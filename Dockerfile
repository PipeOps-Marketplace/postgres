FROM postgres:14

# Only need openssl
RUN apt-get update && apt-get install -y --no-install-recommends openssl \
 && rm -rf /var/lib/apt/lists/*

# Runs once on cluster init (when PGDATA is empty)
COPY --chmod=755 init-ssl.sh /docker-entrypoint-initdb.d/10-init-ssl.sh

# Runs on every start to (re)generate/refresh if missing/expiring, then
# delegates to the official entrypoint
COPY --chmod=755 wrapper.sh /usr/local/bin/wrapper.sh
ENTRYPOINT ["wrapper.sh"]

# same as base image
CMD ["postgres"]
