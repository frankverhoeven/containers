FROM php:8.6-fpm

WORKDIR /var/www/html

# Released excimer and phpredis versions do not build on PHP 8.6 yet, and
# install-php-extensions cannot build these commits (excimer has no package.xml,
# phpredis needs git submodules), so they are compiled from source below.
ARG EXCIMER_COMMIT=34183f9487bf95cd5b8dab50af737d19de5179f7
ARG PHPREDIS_COMMIT=a6ce1e60b3e81ce3b25174aa5aaefd5590dc64fd

COPY --link --from=mlocati/php-extension-installer /usr/bin/install-php-extensions /usr/local/bin/

# Generic updates & dependencies
RUN set -eux \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        bash \
        git \
        libfcgi-bin \
        openssh-client \
        unzip \
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
COPY --link php/8.6-fpm/php.ini $PHP_INI_DIR/conf.d/90-base.ini
COPY --link php/php.dev.ini $PHP_INI_DIR/conf.d/99-dev.ini.disabled
COPY --link php/www.conf /usr/local/etc/php-fpm.d/www.conf

RUN set -eux \
    && mkdir -p /composer/cache \
    && chown -R www-data:www-data /composer

EXPOSE 9000
