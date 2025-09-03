FROM postgres:14

# Only need openssl; keep official entrypoint intact
RUN apt-get update && apt-get install -y --no-install-recommends openssl && rm -rf /var/lib/apt/lists/*

# Where to place certs (writable even when PGDATA PV forbids chown)
ENV SSL_DIR=/var/run/postgresql/certs
ENV PGDATA=/var/lib/postgresql/data/pgdata

# Run during first init only
COPY --chmod=755 10-init-ssl.sh /docker-entrypoint-initdb.d/10-init-ssl.sh
# do NOT override entrypoint; keep postgres' own
# ENTRYPOINT/CMD stay from upstream
