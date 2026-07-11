#!/bin/bash

# exit as soon as any of these commands fail, this prevents starting a database without certificates
set -e

# Make sure there is a PGDATA variable available
if [ -z "$PGDATA" ]; then
  echo "Missing PGDATA variable"
  exit 1
fi

# Set up needed variables
# Use $PGDATA to support custom data directory paths (e.g., /var/lib/postgresql/data/pgdata)
SSL_DIR="$PGDATA/certs"
INIT_SSL_SCRIPT="/docker-entrypoint-initdb.d/init-ssl.sh"
POSTGRES_CONF_FILE="$PGDATA/postgresql.conf"

# Regenerate if the certificate is not a x509v3 certificate
if [ -f "$SSL_DIR/server.crt" ] && ! openssl x509 -noout -text -in "$SSL_DIR/server.crt" | grep -q "DNS:localhost"; then
  echo "Did not find a x509v3 certificate, regenerating certificates..."
  bash "$INIT_SSL_SCRIPT"
fi

# Regenerate if the certificate has expired or will expire
# 2592000 seconds = 30 days
if [ -f "$SSL_DIR/server.crt" ] && ! openssl x509 -checkend 2592000 -noout -in "$SSL_DIR/server.crt"; then
  echo "Certificate has or will expire soon, regenerating certificates..."
  bash "$INIT_SSL_SCRIPT"
fi

# Generate a certificate if the database was initialized but is missing a certificate
# Useful when going from the base postgres image to this ssl image
if [ -f "$POSTGRES_CONF_FILE" ] && [ ! -f "$SSL_DIR/server.crt" ]; then
  echo "Database initialized without certificate, generating certificates..."
  bash "$INIT_SSL_SCRIPT"
fi

# Normalize TLS private key permissions before postgres starts.
# Postgres FATALs on keys with group/other access when owned by the DB user:
#   "private key file has group or world access"
#   "File must have permissions u=rw (0600) or less if owned by the database user,
#    or permissions u=rw,g=r (0640) or less if owned by root."
# init-ssl.sh already chmod's on generate, but:
#   - volume restore / restic / backup tools can rewrite keys with umask 002 → 0660
#   - cert regeneration paths can leave root.key/server.key loose
# Always re-apply here so every boot self-heals (same class as redis SETPCAP
# capability hardening in the provisioner template).
normalize_ssl_key_perms() {
  local dir="$1"
  [ -d "$dir" ] || return 0
  local f uid
  for f in "$dir"/*.key; do
    [ -f "$f" ] || continue
    uid="$(stat -c %u "$f" 2>/dev/null || echo 999)"
    if [ "$uid" = "0" ]; then
      # root-owned: Postgres allows ≤0640
      chmod 640 "$f" 2>/dev/null || chmod 600 "$f" 2>/dev/null || true
    else
      # postgres (or other non-root) owned: must be ≤0600
      chmod 600 "$f" 2>/dev/null || true
    fi
  done
  chmod 700 "$dir" 2>/dev/null || true
}

normalize_ssl_key_perms "$SSL_DIR"
# Railway-style layout keeps certs next to the volume root even when
# PGDATA is a subdirectory (…/data/pgdata).
if [ "$SSL_DIR" != "/var/lib/postgresql/data/certs" ]; then
  normalize_ssl_key_perms "/var/lib/postgresql/data/certs"
fi

# unset PGHOST to force psql to use Unix socket path
# this is specific to Railway and allows
# us to use PGHOST after the init
unset PGHOST

## unset PGPORT also specific to Railway
## since postgres checks for validity of
## the value in PGPORT we unset it in case
## it ends up being empty
unset PGPORT

# Call the entrypoint script with the
# appropriate PGHOST & PGPORT and redirect
# the output to stdout if LOG_TO_STDOUT is true
if [[ "$LOG_TO_STDOUT" == "true" ]]; then
    /usr/local/bin/docker-entrypoint.sh "$@" 2>&1
else
    /usr/local/bin/docker-entrypoint.sh "$@"
fi
