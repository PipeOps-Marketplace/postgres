#!/usr/bin/env bash
# exit early and loudly
set -euo pipefail

umask 077   # ensure new files are 600 by default

: "${PGDATA:?PGDATA must be set}"  # official postgres image sets this

SSL_DIR="${PGDATA}/certs"
SSL_SERVER_CRT="${SSL_DIR}/server.crt"
SSL_SERVER_KEY="${SSL_DIR}/server.key"
SSL_SERVER_CSR="${SSL_DIR}/server.csr"
SSL_ROOT_KEY="${SSL_DIR}/root.key"
SSL_ROOT_CRT="${SSL_DIR}/root.crt"
SSL_V3_EXT="${SSL_DIR}/v3.ext"
POSTGRES_CONF_FILE="${PGDATA}/postgresql.conf"

# hostnames/SANs to embed; adjust to your service DNS if not localhost
CN="${SSL_CN:-localhost}"
ALT_NAMES="${SSL_ALT_NAMES:-DNS:localhost}"

# create cert dir (no sudo)
mkdir -p "${SSL_DIR}"
chmod 700 "${SSL_DIR}"

# ensure current user can write PGDATA (important if running as postgres)
touch "${PGDATA}/.__permcheck" && rm -f "${PGDATA}/.__permcheck" || {
  echo "ERROR: Current user cannot write to ${PGDATA}. Fix volume perms or fsGroup."
  exit 1
}

# ----- Generate a minimal local CA if missing -----
if [[ ! -s "${SSL_ROOT_CRT}" || ! -s "${SSL_ROOT_KEY}" ]]; then
  openssl req -new -x509 \
    -days "${SSL_CERT_DAYS:-820}" -nodes -text \
    -out "${SSL_ROOT_CRT}" -keyout "${SSL_ROOT_KEY}" \
    -subj "/CN=root-ca"
  chmod 600 "${SSL_ROOT_KEY}"
fi

# ----- Generate a server key/cert if missing -----
if [[ ! -s "${SSL_SERVER_KEY}" || ! -s "${SSL_SERVER_CRT}" ]]; then
  # fresh key + CSR
  openssl req -new -nodes -text \
    -out "${SSL_SERVER_CSR}" -keyout "${SSL_SERVER_KEY}" \
    -subj "/CN=${CN}"

  chmod 600 "${SSL_SERVER_KEY}"

  # Proper v3 extension for a **server** cert (CA:FALSE, serverAuth, SANs)
  cat > "${SSL_V3_EXT}" <<EOF
basicConstraints = critical, CA:FALSE
keyUsage = critical, digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth
subjectAltName = ${ALT_NAMES}
authorityKeyIdentifier = keyid, issuer
EOF

  openssl x509 -req -in "${SSL_SERVER_CSR}" \
    -extfile "${SSL_V3_EXT}" -days "${SSL_CERT_DAYS:-820}" \
    -CA "${SSL_ROOT_CRT}" -CAkey "${SSL_ROOT_KEY}" -CAcreateserial \
    -out "${SSL_SERVER_CRT}"

  # final hardening; Postgres requires the key to be not group/world-readable
  chmod 600 "${SSL_SERVER_KEY}" "${SSL_SERVER_CRT}" "${SSL_ROOT_CRT}"
fi

# Make sure files are owned by the server user if we're running as postgres
# (If the image runs as root + gosu later, ownership is still fine.)
if id -u postgres &>/dev/null; then
  chown -R postgres:postgres "${SSL_DIR}"
fi

# ----- Patch postgresql.conf idempotently -----
add_conf() {
  local key="$1" val="$2"
  if ! grep -qE "^\s*${key}\s*=" "${POSTGRES_CONF_FILE}" 2>/dev/null; then
    printf "%s = '%s'\n" "${key}" "${val}" >> "${POSTGRES_CONF_FILE}"
  else
    # replace existing value in-place
    perl -0777 -pe "s|^\\s*${key}\\s*=.*$|${key} = '${val}'|m" \
      -i "${POSTGRES_CONF_FILE}"
  fi
}

add_conf ssl on
add_conf ssl_cert_file "${SSL_SERVER_CRT}"
add_conf ssl_key_file  "${SSL_SERVER_KEY}"
add_conf ssl_ca_file   "${SSL_ROOT_CRT}"

echo "SSL configured. Cert: ${SSL_SERVER_CRT}, Key: ${SSL_SERVER_KEY}, CA: ${SSL_ROOT_CRT}"
