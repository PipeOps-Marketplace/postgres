# Postgres On PipeOps

This repository contains the logic to build SSL-enabled Postgres images.

By default, when you deploy Postgres from the offical Postgres template on PipeOps, the image that is used is built from this repository!

[![Deploy on PipeOps](https://pub-a1fbf367a4cd458487cfa3f29154ac93.r2.dev/Default.png)](https://railway.app/template/0ELOuE?referralCode=IQhE0B)

### Why though?

The offical Postgres image in Docker hub does not come with SSL baked in.

Since this could pose a problem for applications or services attempting to connect to Postgres services, we decided to roll our own Postgres image with SSL enabled right out of the box.

### How does it work?

The Dockerfiles contained in this repository start with the official Postgres image as base.  Then the `init-ssl.sh` script is copied into the `docker-entrypoint-initdb.d/` directory to be executed upon initialization.

#### Cert expiry
By default, the cert expiry is set to 820 days.  You can control this by configuring the `SSL_CERT_DAYS` environment variable as needed.

### A note about ports

By default, this image is hardcoded to listen on port `5432` regardless of what is set in the `PGPORT` environment variable.If you need to change this behavior, feel free to build your own image without passing the `--port` parameter to the `CMD` command in the Dockerfile.
