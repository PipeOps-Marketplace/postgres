#!/usr/bin/env bash
set -euo pipefail
umask 077

: "${PGDATA:?PGDATA must be set}"

SSL_DIR="${PGDATA}/certs"
SERVER_KEY="${SSL_DIR}/server.key"
SERVER_CRT="${SSL_DIR}/server.crt"
SERVER_CSR="${SSL_DIR}/server.csr"
ROOT_KEY="${SSL_DIR}/root.key"
ROOT_CRT="${SSL_DIR}/root.crt"
EXTFILE="${SSL_DIR}/v3.ext"
CONF="${PGDATA}/postgresql.conf"

CN="${SSL_CN:-localhost}"
ALT_NAMES="${SSL_ALT_NAMES:-DNS:localhost}"
DAYS="${SSL_CERT_DAYS:-820}"

mkdir -p "${SSL_DIR}"
chmod 700 "${SSL_DIR}"

# Create a tiny local CA if missing
if [[ ! -s "${ROOT_KEY}" || ! -s "${ROOT_CRT}" ]]; then
  openssl req -new -x509 -nodes -text -days "${DAYS}" \
    -keyout "${ROOT_KEY}" -out "${ROOT_CRT}" -subj "/CN=root-ca"
  chmod 600 "${ROOT_KEY}" "${ROOT_CRT}"
fi

# Create server key/cert if missing
if [[ ! -s "${SERVER_KEY}" || ! -s "${SERVER_CRT}" ]]; then
  openssl req -new -nodes -text -keyout "${SERVER_KEY}" -out "${SERVER_CSR}" \
    -subj "/CN=${CN}"
  chmod 600 "${SERVER_KEY}"

  cat > "${EXTFILE}" <<EOF
basicConstraints = critical, CA:FALSE
keyUsage = critical, digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth
subjectAltName = ${ALT_NAMES}
authorityKeyIdentifier = keyid, issuer
EOF

  openssl x509 -req -in "${SERVER_CSR}" -days "${DAYS}" \
    -extfile "${EXTFILE}" \
    -CA "${ROOT_CRT}" -CAkey "${ROOT_KEY}" -CAcreateserial \
    -out "${SERVER_CRT}"

  chmod 600 "${SERVER_CRT}"
fi

# Idempotently set SSL settings
add_conf() {
  local k="$1" v="$2"
  if grep -qE "^\s*${k}\s*=" "${CONF}" 2>/dev/null; then
    # replace existing
    perl -0777 -pe "s|^\\s*${k}\\s*=.*$|${k} = '${v}'|m" -i "${CONF}"
  else
    printf "%s = '%s'\n" "${k}" "${v}" >> "${CONF}"
  fi
}

add_conf ssl on
add_conf ssl_cert_file "${SERVER_CRT}"
add_conf ssl_key_file  "${SERVER_KEY}"
add_conf ssl_ca_file   "${ROOT_CRT}"

echo "| $(date +"%d-%m-%Y %H:%M:%S") SSL configured at ${SSL_DIR}"
