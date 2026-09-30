FROM dunglas/frankenphp:php8.5 AS toolchain

WORKDIR /app

# Generic updates & dependencies
RUN set -eux \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        bash \
        brotli \
        git \
        openssh-client \
        unzip \
        zstd \
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
COPY --link php/8.5-frankenphp/php.ini $PHP_INI_DIR/conf.d/90-base.ini
COPY --link php/php.dev.ini $PHP_INI_DIR/conf.d/99-dev.ini.disabled
COPY --link php/8.5-frankenphp/Caddyfile /etc/frankenphp/Caddyfile

# Ensure required directories exist and have the correct permissions
RUN <<-EOF
	mkdir -p /data/caddy /config/caddy
	chown -R www-data:www-data /data /config
	# Composer
	mkdir -p /composer/cache
    chown -R www-data:www-data /composer
    # Source root
	chown -R www-data:www-data /app
	# Remove setuid/setgid bits
	find / -perm /6000 -type f -exec chmod a-s {} + 2>/dev/null || true
EOF

# Purge in a preparation stage, then copy its filesystem into a fresh image.
# Deleting tools in a child of the upstream image would retain their old layers.
FROM toolchain AS runtime-clean
COPY php/8.5-frankenphp/prepare-runtime.sh /usr/local/bin/prepare-runtime
RUN sh /usr/local/bin/prepare-runtime

FROM scratch AS runtime
COPY --from=runtime-clean / /
ENV PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" \
    PHP_INI_DIR="/usr/local/etc/php" \
    XDG_CONFIG_HOME="/config" \
    XDG_DATA_HOME="/data" \
    GODEBUG="cgocheck=0"
WORKDIR /app
# BuildKit preserves the capability prepared before the filesystem copy.
# Assert it without modifying the binary into another full-size layer.
RUN getcap /usr/local/bin/frankenphp | grep -q "cap_net_bind_service=ep"
EXPOSE 80 443 443/udp 2019
HEALTHCHECK CMD curl -f http://localhost:2019/metrics || exit 1
ENTRYPOINT ["docker-php-entrypoint"]
CMD ["--config", "/etc/frankenphp/Caddyfile", "--adapter", "caddyfile"]

FROM toolchain AS test-fixtures
COPY tests/frankenphp-assets-fixtures.sh /tmp/assets-fixtures.sh
RUN sh /tmp/assets-fixtures.sh /fixtures

FROM runtime AS runtime-test
COPY --from=test-fixtures /fixtures /fixtures

# Keep an untargeted build and existing tags compatible with development.
FROM toolchain AS dev
