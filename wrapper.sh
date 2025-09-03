#!/usr/bin/env bash
set -euo pipefail

: "${PGDATA:?PGDATA must be set}"   # e.g., /var/lib/postgresql/data/pgdata

SSL_DIR="${PGDATA}/certs"
POSTGRES_CONF_FILE="${PGDATA}/postgresql.conf"
CRT="${SSL_DIR}/server.crt"

mkdir -p "${SSL_DIR}"
chmod 700 "${SSL_DIR}"

# If cert exists but lacks SAN or is expiring in <30d, regenerate via init script
if [[ -f "${CRT}" ]]; then
  if ! openssl x509 -noout -text -in "${CRT}" | grep -q "X509v3 Subject Alternative Name"; then
    echo "| $(date +"%d-%m-%Y %H:%M:%S") Found non-SAN certificate, regenerating..."
    bash /docker-entrypoint-initdb.d/10-init-ssl.sh
  elif ! openssl x509 -checkend 2592000 -noout -in "${CRT}"; then
    echo "| $(date +"%d-%m-%Y %H:%M:%S") Certificate expiring soon, regenerating..."
    bash /docker-entrypoint-initdb.d/10-init-ssl.sh
  fi
fi

# If DB was already initialized but no certs yet (e.g., upgraded image), generate
if [[ -f "${POSTGRES_CONF_FILE}" && ! -f "${CRT}" ]]; then
  echo "| $(date +"%d-%m-%Y %H:%M:%S") Database initialized without certificate, generating certificates..."
  bash /docker-entrypoint-initdb.d/10-init-ssl.sh
fi

# hand off to the official entrypoint
exec /usr/local/bin/docker-entrypoint.sh "$@"
