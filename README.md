# Postgres On PipeOps

This repository contains the logic to build SSL-enabled Postgres images.

By default, when you deploy Postgres from the offical Postgres template on PipeOps, the image that is used is built from this repository!

### How does it work?

The Dockerfiles contained in this repository start with the official Postgres image as base.  Then the `init-ssl.sh` script is copied into the `docker-entrypoint-initdb.d/` directory to be executed upon initialization.

### Environment Variables

#### SSL_CERT_DAYS
By default, the cert expiry is set to 820 days. You can control this by configuring the `SSL_CERT_DAYS` environment variable as needed.

#### SSL_HOSTNAME
By default, the SSL certificate is generated with `localhost` as the Common Name (CN) and Subject Alternative Name (SAN). This works for local connections but causes SSL verification failures when connecting remotely via a proxy or custom domain.

Set `SSL_HOSTNAME` to your public hostname (e.g., `mydb.example.com`) to include it in the certificate's SAN. The certificate will always include `localhost`, `0.0.0.0`, and `127.0.0.1` as valid SANs regardless of this setting.

**Example:**
```bash
SSL_HOSTNAME=mydb.pipeops.app
```

This allows `sslmode=require` connections to work properly when connecting via the specified hostname.

### A note about ports

By default, this image is hardcoded to listen on port `5432` regardless of what is set in the `PGPORT` environment variable.If you need to change this behavior, feel free to build your own image without passing the `--port` parameter to the `CMD` command in the Dockerfile.
