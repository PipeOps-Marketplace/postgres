# Postgres On PipeOps

This repository contains the logic to build SSL-enabled Postgres images.

By default, when you deploy Postgres from the offical Postgres template on PipeOps, the image that is used is built from this repository!

### How does it work?

The Dockerfiles contained in this repository start with the official Postgres image as base.  Then the `init-ssl.sh` script is copied into the `docker-entrypoint-initdb.d/` directory to be executed upon initialization.

#### Cert expiry
By default, the cert expiry is set to 820 days.  You can control this by configuring the `SSL_CERT_DAYS` environment variable as needed.

### A note about ports

By default, this image is hardcoded to listen on port `5432` regardless of what is set in the `PGPORT` environment variable.If you need to change this behavior, feel free to build your own image without passing the `--port` parameter to the `CMD` command in the Dockerfile.
