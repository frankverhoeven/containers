# Docker Containers for Web Development

This repository contains a collection of Docker container configurations optimized for web development. These containers are designed to be used as base images for your web applications, providing a consistent and reliable environment for development and production.

## Repository Structure

- `nginx/` - Nginx web server container configurations
- `php/` - PHP-FPM, FrankenPHP and Swoole container configurations
- `Makefile` - Build automation scripts

## Available Containers

### Nginx

A customized Nginx container based on the official Alpine image with:
- Latest Nginx
- Optimized configuration for web applications
- CloudFlare integration
- Custom configuration files

**compose.yaml**
```yaml
services:
    nginx:
        image: ghcr.io/frankverhoeven/nginx
        ports:
            - "80:80"
        volumes:
            - ./:/var/www/html
        depends_on:
            - php
```

**Dockerfile**
```Dockerfile
FROM ghcr.io/frankverhoeven/nginx
```

### PHP versions

FPM, FrankenPHP and the FrankenPHP runtime are published for PHP 8.5 and PHP 8.6.
Swap `8.5` for `8.6` in the image name, for example
`ghcr.io/frankverhoeven/php-8.6-fpm`. Swoole is PHP 8.5 only until Swoole
supports PHP 8.6.

The PHP 8.6 images build igbinary, imagick, phpredis, excimer and Xdebug from
pinned upstream commits, because their latest releases do not support PHP 8.6
yet. Switch back to releases once they do.

### PHP

A customized PHP-FPM container based on Debian Bookworm:

- PHP 8.5 FPM on Debian Bookworm
- Common PHP extensions pre-installed
- Xdebug (disabled by default)
- Composer 2
- Optimized configuration for web applications

**Available extensions**: bcmath, exif, gd, gmp, igbinary, imagick, intl, mbstring, opcache, pcntl, pdo_pgsql, redis, uuid, xsl, zip, xdebug

**compose.yaml**
```yaml
services:
    php:
        image: ghcr.io/frankverhoeven/php-8.5-fpm
        volumes:
            - ./:/var/www/html
```

**Dockerfile**
```Dockerfile
FROM ghcr.io/frankverhoeven/php-8.5-fpm
```

### PHP (FrankenPHP)

A customized FrankenPHP container based on the official `dunglas/frankenphp` image:

- PHP 8.5 with FrankenPHP (Caddy-based application server)
- Same set of PHP extensions as the FPM image
- Xdebug (disabled by default)
- Composer 2
- Working directory: `/app`

**Available extensions**: bcmath, exif, gd, gmp, igbinary, imagick, intl, mbstring, opcache, pcntl, pdo_pgsql, redis, uuid, xsl, zip, xdebug

**compose.yaml**
```yaml
services:
    php:
        image: ghcr.io/frankverhoeven/php-8.5-frankenphp
        ports:
            - "80:80"
        volumes:
            - ./:/app
        environment:
            # Enable hot reloading on development environments
            # https://frankenphp.dev/docs/symfony/#hot-reload-for-symfony
            CADDY_SERVER_EXTRA_DIRECTIVES: |
                mercure {
                    anonymous
                }
            FRANKENPHP_SITE_CONFIG: 'hot_reload'
            FRANKENPHP_WORKER_CONFIG: 'watch'
            # Raise logging level in production environments
            CADDY_SERVER_LOG_OPTIONS: 'level WARN'
```

**Dockerfile**
```Dockerfile
FROM ghcr.io/frankverhoeven/php-8.5-frankenphp
```

#### Static asset performance

The file server serves existing static files directly, outside the PHP worker pool.
It supports precompressed `.br`, `.zst`, and `.gz` sidecar files, preferring Brotli,
then Zstandard, then gzip when the client gives them equal priority. This avoids
per-request compression and lets builds use higher compression levels. Clients
without a supported sidecar still receive the original file or on-demand
compression through the existing `encode` directive. Keep each original file
alongside its sidecars and regenerate them whenever its contents change.

Brotli and Zstandard CLI tools are included for application builds. For Symfony
AssetMapper versions supporting precompression, enable it in production:

```yaml
# config/packages/asset_mapper.yaml
when@prod:
    framework:
        asset_mapper:
            precompress:
                format: ['brotli', 'zstandard', 'gzip']
```

Then run `APP_ENV=prod php bin/console asset-map:compile` after installing the
application dependencies and building its assets. Other build pipelines can
generate the same sidecars using `brotli`, `zstd`, and `gzip`.

For a directory containing **only content-versioned public assets**, browser
caching can also avoid repeat downloads and validation requests. Opt in using
the existing configuration hook (merge this into any existing directives):

```yaml
environment:
    CADDY_SERVER_EXTRA_DIRECTIVES: |
        @immutableAssets {
            path /assets/*
            file {path}
            not path *.php *.json
        }
        header @immutableAssets Cache-Control "public, max-age=31536000, immutable" {
            match status 200 206 304
        }
```

Use this only when a changed asset always gets a new URL. JSON manifests are
excluded because build tools commonly give them stable names. The base image
does not impose a cache lifetime on mutable files, uploaded media, or application
responses; the file server retains its standard ETag and Last-Modified validators.

References: [FrankenPHP Symfony integration](https://frankenphp.dev/docs/symfony/#pre-compressing-assets),
[Caddy file server](https://caddyserver.com/docs/caddyfile/directives/file_server),
and [Symfony AssetMapper precompression](https://symfony.com/doc/current/frontend/asset_mapper.html#pre-compressing-assets).

### PHP (Swoole)

PHP 8.5 CLI with Swoole 6.2.4, the same PHP extensions, disabled Xdebug,
Composer and asset compression tools as the FrankenPHP development image.
Caddy (from the Mercure image) handles TLS, HTTP/2, HTTP/3, Mercure, static files,
and precompressed Brotli/Zstandard/gzip sidecars. Dynamic requests go to a
persistent Swoole worker on loopback port 8000. On-demand compression uses
Zstandard/gzip.

For Symfony applications using `vendor/autoload_runtime.php`, change the base
image to `ghcr.io/frankverhoeven/php-8.5-swoole`. Keep the application in `/app`,
the public directory at `/app/public`, and the preload file at
`/app/config/preload.php`. The image bundles
[`runtime/swoole` 1.0.0](https://github.com/php-runtime/swoole), registers its
autoloader alongside the application's Composer loader, and selects it only during HTTP startup.
The pinned adapter includes fixes for query strings and repeated response headers
(including cookies). No Composer dependency or front-controller change is required. Console commands
retain the application's own runtime. Supported Symfony Runtime versions are
5.4.26+, 6.3.2+, 7.x and 8.x (within the adapter's constraints).

```Dockerfile
FROM ghcr.io/frankverhoeven/php-8.5-swoole
```

```yaml
services:
    php:
        image: ghcr.io/frankverhoeven/php-8.5-swoole
        ports:
            - "80:80"
            - "443:443"
            - "443:443/udp"
        volumes:
            - ./:/app
        environment:
            SERVER_NAME: localhost
            SWOOLE_WORKERS: 2
            SWOOLE_MAX_REQUESTS: 1000
            CADDY_SERVER_LOG_OPTIONS: 'level WARN'
```

`SERVER_NAME`, `CADDY_GLOBAL_OPTIONS`, `CADDY_EXTRA_CONFIG`,
`CADDY_SERVER_EXTRA_DIRECTIVES` (including Mercure) and
`CADDY_SERVER_LOG_OPTIONS` remain available. The Caddyfile lives at
`/etc/caddy/Caddyfile`. Caddy state uses `/data` and `/config`, as in FrankenPHP.
The default healthcheck checks both the Caddy admin API and a Swoole HTTP worker;
override it if disabling or moving the admin API.

FrankenPHP-specific `FRANKENPHP_*` directives, `hot_reload`, and direct calls to
`frankenphp_handle_request()` are not supported. This replacement targets
Symfony Runtime front controllers, not arbitrary FrankenPHP worker scripts.
Use `SWOOLE_WORKERS` (default 2) to set worker count and `SWOOLE_MAX_REQUESTS`
(default 1000, 0 for unlimited) to recycle workers. Coroutines are disabled to
keep shared application services sequential within each worker. Restart the
container to load source changes, or enable the shared development INI and
restart as needed. Applications overriding their runtime in PHP or customizing
`APP_RUNTIME_OPTIONS` should review those settings when switching.

The entrypoint supervises both services and stops the container if either
exits. Command overrides such as `php bin/console` and `composer install`
work as usual. Existing FrankenPHP images and build targets remain available.
CI tests and publishes Swoole for amd64 and arm64 under `latest` and version tags.

```sh
make swoole-build swoole-test
# Intel hosts: make swoole-build swoole-test SWOOLE_PLATFORM=linux/amd64
# Or: docker compose -f tests/docker-compose.test.yml run --build --rm php-swoole
```

#### Why Debian instead of Alpine?

While Alpine images are smaller, **PHP performance on Alpine is approximately 10% lower than on Debian**. For PHP applications, this performance difference outweighs the image size benefit.

**Technical Details**: Alpine Linux uses musl libc instead of glibc (GNU C Library). While musl is smaller and simpler, PHP's performance characteristics differ significantly between the two:
- glibc (Debian) has more optimized memory allocation and string operations
- musl's malloc implementation can be slower for PHP's memory-intensive workloads
- PHP's core and many extensions are primarily developed and tested against glibc

For production PHP workloads, the 10% performance improvement from using Debian typically provides better value than the reduced image size and faster deployment times of Alpine.

#### Development INI

Enable development configuration:

```Dockerfile
RUN mv /usr/local/etc/php/conf.d/99-dev.ini.disabled /usr/local/etc/php/conf.d/99-dev.ini
```

If using `APP_DEBUG` (Symfony) env vars you could use:

```Dockerfile
RUN if [ "${APP_DEBUG}" = "1" ]; then \
        mv /usr/local/etc/php/conf.d/99-dev.ini.disabled /usr/local/etc/php/conf.d/99-dev.ini; \
    fi
```

#### Healthcheck

```yaml
services:
    php:
        healthcheck:
            test: "SCRIPT_NAME=/ping SCRIPT_FILENAME=/ping REQUEST_METHOD=GET cgi-fcgi -bind -connect 127.0.0.1:9000 | grep 'pong' || exit 1"
            start_period: 10s
            interval: 30s
            timeout: 10s
            retries: 3
```

## Usage

### Building Images

Use the provided Makefile to build images:

```bash
# Build PHP (FPM)
make build php/8.5-fpm/Dockerfile

# Build PHP (FrankenPHP)
make build php/8.5-frankenphp/Dockerfile

# Build PHP (Swoole)
make build php/8.5-swoole/Dockerfile

# PHP 8.6 variants live next to them
make build php/8.6-fpm/Dockerfile

# Build Nginx
make build nginx/Dockerfile
```

### Testing Images

Test images locally using Docker Compose:

```bash
cd tests
docker compose -f docker-compose.test.yml up --build php-debian
# Includes HTTP checks for precompressed files, fallback compression and routing.
docker compose -f docker-compose.test.yml run --build --rm php-frankenphp
# PHP 8.6 services carry a -8.6 suffix
docker compose -f docker-compose.test.yml run --build --rm php-debian-8.6
```

### Local Development

Create a `docker-compose.yml` file in your project that references these images and customize as needed.

## License

This project is licensed under the MIT License.

### Lean FrankenPHP runtime

The existing default/version tags remain development images. The `runtime` and
`<version>-runtime` tags contain the same Debian PHP/FrankenPHP runtime and PHP
extensions, without compilers, Composer, Git, SSH, Xdebug or asset build tools.
Build application dependencies/assets with the default image, then copy runtime
artifacts into an image based on the runtime tag. Pin that tag to a tested digest
for deployment. The cleaned filesystem is copied into a fresh final stage so
removed upstream build tools do not remain in inherited layers.

Local builds and tests (use `linux/amd64` on Intel hosts):

```sh
make frankenphp-build frankenphp-test FRANKENPHP_PLATFORM=linux/arm64
make frankenphp-size
```

HTTP fixtures are compressed in the development stage, then copied into the
runtime test stage. Tests cover worker routing, sidecar negotiation, PHP
extensions, image processing, timezone data and missing shared libraries on both
amd64 and arm64 in CI. Runtime consumers must supply `/app/config/preload.php`,
just like consumers of the existing development image.
