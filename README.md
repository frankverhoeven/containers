# Docker Containers for Web Development

This repository contains a collection of Docker container configurations optimized for web development. These containers are designed to be used as base images for your web applications, providing a consistent and reliable environment for development and production.

## Repository Structure

- `nginx/` - Nginx web server container configurations
- `php/` - PHP-FPM container configurations
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
# Build PHP
make build php/8.5-fpm/Dockerfile

# Build Nginx
make build nginx/Dockerfile
```

### Testing Images

Test images locally using Docker Compose:

```bash
cd tests
docker compose -f docker-compose.test.yml up --build php-debian
```

### Local Development

Create a `docker-compose.yml` file in your project that references these images and customize as needed.

## License

This project is licensed under the MIT License.
