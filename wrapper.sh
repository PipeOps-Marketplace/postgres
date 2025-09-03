#!/usr/bin/env bash
set -euo pipefail

: "${PGDATA:?PGDATA must be set}"   # e.g., /var/lib/postgresql/data/pgdata
SSL_DIR="/var/lib/postgresql/certs"  # Keep SSL certs outside PGDATA
POSTGRES_CONF_FILE="${PGDATA}/postgresql.conf"
CRT="${SSL_DIR}/server.crt"

# Create SSL directory
mkdir -p "${SSL_DIR}"
chmod 700 "${SSL_DIR}"

# Function to setup SSL configuration
setup_ssl() {
    echo "| $(date +"%d-%m-%Y %H:%M:%S") Setting up SSL certificates..."
    bash /docker-entrypoint-initdb.d/10-init-ssl.sh
}

# Check if database is already initialized
if [[ -f "${POSTGRES_CONF_FILE}" ]]; then
    echo "| $(date +"%d-%m-%Y %H:%M:%S") Database already initialized, checking SSL setup..."
    
    # If cert exists but lacks SAN or is expiring in <30d, regenerate
    if [[ -f "${CRT}" ]]; then
        if ! openssl x509 -noout -text -in "${CRT}" | grep -q "X509v3 Subject Alternative Name"; then
            echo "| $(date +"%d-%m-%Y %H:%M:%S") Found non-SAN certificate, regenerating..."
