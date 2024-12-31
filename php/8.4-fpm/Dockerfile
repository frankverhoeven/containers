FROM php:8.4-fpm-alpine

WORKDIR /var/www/html

# Generic updates & dependencies
RUN set -eux \
    && apk update \
    && apk upgrade \
    && apk add --no-cache \
        gettext \
        git \
        icu-dev \
        libpq-dev \
        libzip \
        openssh-client \
        yaml-dev \
        zlib-dev \
    && rm -rf /var/cache/apk/*

# PHP Extensions
RUN docker-php-ext-install -j$(nproc) \
    intl \
    opcache \
    pdo \
    pdo_pgsql

# Install composer
COPY --link --from=composer:2 /usr/bin/composer /usr/local/bin/composer

# Base Configuration
COPY --link php/php.ini /usr/local/etc/php/conf.d/90-base.ini

EXPOSE 9000
