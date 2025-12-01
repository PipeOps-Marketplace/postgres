#!/bin/bash

# exit as soon as any of these commands fail, this prevents starting a database without certificates
set -e

# Set up needed variables
# Use $PGDATA to support custom data directory paths (e.g., /var/lib/postgresql/data/pgdata)
SSL_DIR="$PGDATA/certs"

SSL_SERVER_CRT="$SSL_DIR/server.crt"
SSL_SERVER_KEY="$SSL_DIR/server.key"
SSL_SERVER_CSR="$SSL_DIR/server.csr"

SSL_ROOT_KEY="$SSL_DIR/root.key"
SSL_ROOT_CRT="$SSL_DIR/root.crt"

SSL_V3_EXT="$SSL_DIR/v3.ext"

POSTGRES_CONF_FILE="$PGDATA/postgresql.conf"

# Create the SSL directory (postgres user owns PGDATA, so no sudo needed)
mkdir -p "$SSL_DIR"

# Generate self-signed 509v3 certificates
# ref: https://www.postgresql.org/docs/16/ssl-tcp.html#SSL-CERTIFICATE-CREATION

openssl req -new -x509 -days "${SSL_CERT_DAYS:-820}" -nodes -text -out "$SSL_ROOT_CRT" -keyout "$SSL_ROOT_KEY" -subj "/CN=root-ca"

chmod og-rwx "$SSL_ROOT_KEY"

# Use SSL_HOSTNAME env var if set and non-empty, otherwise default to localhost
SSL_CN="${SSL_HOSTNAME:-localhost}"
if [ -z "$SSL_CN" ]; then
  SSL_CN="localhost"
fi

openssl req -new -nodes -text -out "$SSL_SERVER_CSR" -keyout "$SSL_SERVER_KEY" -subj "/CN=$SSL_CN"

chmod og-rwx "$SSL_SERVER_KEY"

# Build SAN list with localhost always included, plus optional custom hostname
# This allows connections via localhost, any IP, and optionally a custom hostname
SAN_LIST="DNS:localhost, IP:0.0.0.0, IP:127.0.0.1"
if [ -n "$SSL_HOSTNAME" ] && [ "$SSL_HOSTNAME" != "localhost" ]; then
  SAN_LIST="$SAN_LIST, DNS:$SSL_HOSTNAME"
fi

cat >| "$SSL_V3_EXT" <<EXTEOF
[v3_req]
authorityKeyIdentifier = keyid, issuer
basicConstraints = critical, CA:TRUE
keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
subjectAltName = $SAN_LIST
EXTEOF

openssl x509 -req -in "$SSL_SERVER_CSR" -extfile "$SSL_V3_EXT" -extensions v3_req -text -days "${SSL_CERT_DAYS:-820}" -CA "$SSL_ROOT_CRT" -CAkey "$SSL_ROOT_KEY" -CAcreateserial -out "$SSL_SERVER_CRT"

# PostgreSQL configuration, enable ssl and set paths to certificate files
cat >> "$POSTGRES_CONF_FILE" <<CONFEOF
ssl = on
ssl_cert_file = '$SSL_SERVER_CRT'
ssl_key_file = '$SSL_SERVER_KEY'
ssl_ca_file = '$SSL_ROOT_CRT'
CONFEOF

echo "SSL certificates generated successfully in $SSL_DIR"
