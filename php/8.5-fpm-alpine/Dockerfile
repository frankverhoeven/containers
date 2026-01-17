FROM php:8.5-fpm-alpine

WORKDIR /var/www/html

COPY --link --from=mlocati/php-extension-installer /usr/bin/install-php-extensions /usr/local/bin/

RUN set -eux \
    && apk add --no-cache \
        git \
        openssh-client \
        unzip \
    && install-php-extensions \
        bcmath \
        exif \
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
    && IPE_DONT_ENABLE=1 install-php-extensions xdebug

COPY --link --from=composer:2 /usr/bin/composer /usr/local/bin/composer
ENV COMPOSER_HOME="/composer" \
    COMPOSER_CACHE_DIR="/composer/cache" \
    COMPOSER_ALLOW_SUPERUSER=1

# Base Configuration
RUN cp $PHP_INI_DIR/php.ini-production $PHP_INI_DIR/php.ini
COPY --link php/php.ini $PHP_INI_DIR/conf.d/90-base.ini
COPY --link php/php.dev.ini $PHP_INI_DIR/conf.d/99-dev.ini.disabled
COPY --link php/www.conf /usr/local/etc/php-fpm.d/www.conf

RUN set -eux \
    && mkdir -p /composer/cache \
    && chown -R www-data:www-data /composer

EXPOSE 9000
