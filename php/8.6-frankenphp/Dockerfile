FROM dunglas/frankenphp:php8.6 AS toolchain

WORKDIR /app

# Released excimer and phpredis versions do not build on PHP 8.6 yet, and
# install-php-extensions cannot build these commits (excimer has no package.xml,
# phpredis needs git submodules), so they are compiled from source below.
ARG EXCIMER_COMMIT=34183f9487bf95cd5b8dab50af737d19de5179f7
ARG PHPREDIS_COMMIT=a6ce1e60b3e81ce3b25174aa5aaefd5590dc64fd

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
        gd \
        gmp \
        igbinary/igbinary@2b1f5d62e3037b07c2a46499ac32091cdb41fb40 \
        Imagick/imagick@55ed2e9fda264395636a2e27e51f31673f5566ab \
        intl \
        mbstring \
        opcache \
        pcntl \
        pdo_pgsql \
        uuid \
        xsl \
        zip \
    && IPE_DONT_ENABLE=1 install-php-extensions xdebug/xdebug@5e19866c1766e38c527f9f94faa170370dc4209f \
    && apt-get update \
    && apt-get install -y --no-install-recommends $PHPIZE_DEPS liblz4-dev libzstd-dev \
    && mkdir /tmp/excimer \
    && curl -fsSL "https://codeload.github.com/wikimedia/mediawiki-php-excimer/tar.gz/${EXCIMER_COMMIT}" \
        | tar -xz -C /tmp/excimer --strip-components=1 \
    && (cd /tmp/excimer && phpize && ./configure && make -j"$(nproc)" && make install) \
    && git clone --quiet https://github.com/phpredis/phpredis.git /tmp/redis \
    && git -C /tmp/redis checkout --quiet "${PHPREDIS_COMMIT}" \
    && git -C /tmp/redis submodule update --quiet --init \
    && (cd /tmp/redis && phpize \
        && ./configure --enable-redis-igbinary --enable-redis-lzf \
            --enable-redis-zstd --with-libzstd --enable-redis-lz4 --with-liblz4 \
        && make -j"$(nproc)" && make install) \
    && docker-php-ext-enable excimer redis \
    && rm -rf /tmp/excimer /tmp/redis \
    && apt-get purge -y $PHPIZE_DEPS liblz4-dev libzstd-dev \
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
COPY --link php/8.6-frankenphp/php.ini $PHP_INI_DIR/conf.d/90-base.ini
COPY --link php/php.dev.ini $PHP_INI_DIR/conf.d/99-dev.ini.disabled
COPY --link php/8.6-frankenphp/Caddyfile /etc/frankenphp/Caddyfile

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
COPY php/8.6-frankenphp/prepare-runtime.sh /usr/local/bin/prepare-runtime
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
