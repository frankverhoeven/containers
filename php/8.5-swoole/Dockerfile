FROM dunglas/mercure AS caddy

FROM php:8.5-cli

WORKDIR /app

ARG SWOOLE_VERSION=6.2.4

COPY --link --from=mlocati/php-extension-installer /usr/bin/install-php-extensions /usr/local/bin/

# Generic updates & dependencies
RUN set -eux \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        bash \
        git \
        brotli \
        curl \
        libcap2-bin \
        tini \
        zstd \
        openssh-client \
        unzip \
    && install-php-extensions \
        bcmath \
        exif \
        excimer \
        gd \
        gmp \
        igbinary \
        imagick \
        intl \
        mbstring \
        opcache \
        pcntl \
        pdo_pgsql \
        redis \
        swoole-${SWOOLE_VERSION} \
        uuid \
        xsl \
        zip \
    && IPE_DONT_ENABLE=1 install-php-extensions xdebug \
    && apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false \
    && apt-get autoremove -y \
    && rm -rf /var/lib/apt/lists/*

# Install composer
COPY --link --from=composer:2 /usr/bin/composer /usr/local/bin/composer
ENV COMPOSER_HOME="/composer" \
    COMPOSER_CACHE_DIR="/composer/cache" \
    COMPOSER_ALLOW_SUPERUSER=1

# Base Configuration
RUN cp $PHP_INI_DIR/php.ini-production $PHP_INI_DIR/php.ini
COPY --link php/8.5-swoole/php.ini $PHP_INI_DIR/conf.d/90-base.ini
COPY --link php/php.dev.ini $PHP_INI_DIR/conf.d/99-dev.ini.disabled
COPY --link --from=caddy /usr/bin/caddy /usr/local/bin/caddy
# Bundle only the adapter; Symfony classes must come from the application.
RUN curl -fsSL https://api.github.com/repos/php-runtime/swoole/tarball/dc987c388351536ec456758b956f4b7697145dfe \
        | tar -xz --strip-components=1 -C /opt --one-top-level=swoole-runtime
COPY --link php/8.5-swoole/runtime.patch /tmp/swoole-runtime.patch
# Preserve query strings and repeated response headers in the pinned adapter.
RUN cd /opt/swoole-runtime && git apply /tmp/swoole-runtime.patch && rm /tmp/swoole-runtime.patch
COPY --link php/8.5-swoole/Caddyfile /etc/caddy/Caddyfile
COPY --link php/8.5-swoole/worker.php /usr/local/lib/swoole-worker.php
COPY --link php/8.5-swoole/start.sh /usr/local/bin/start-swoole
COPY --link php/8.5-swoole/healthcheck.sh /usr/local/bin/swoole-healthcheck
RUN chmod +x /usr/local/bin/start-swoole /usr/local/bin/swoole-healthcheck \
    && mkdir -p /composer/cache /data/caddy /config/caddy \
    && chown -R www-data:www-data /app /composer /data /config \
    && setcap cap_net_bind_service=+ep /usr/local/bin/caddy

ENV XDG_CONFIG_HOME=/config \
    XDG_DATA_HOME=/data
EXPOSE 80 443 443/udp 2019
HEALTHCHECK --start-period=30s CMD ["swoole-healthcheck"]
ENTRYPOINT ["tini", "-g", "--", "start-swoole"]
CMD ["--config", "/etc/caddy/Caddyfile", "--adapter", "caddyfile"]
