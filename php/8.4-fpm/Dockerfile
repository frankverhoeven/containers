FROM php:8.4-fpm-alpine

WORKDIR /var/www/html

# Generic updates & dependencies
RUN set -eux \
    && apk update \
    && apk upgrade \
    && apk add --no-cache \
        bash \
        git \
        openssh-client \
        unzip \
    && rm -rf /var/cache/apk/*

COPY --link --from=mlocati/php-extension-installer /usr/bin/install-php-extensions /usr/local/bin/

# PHP Extensions
RUN install-php-extensions \
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
    xsl \
    zip \
    # https://gitlab.alpinelinux.org/alpine/aports/-/issues/13415
    && rm /usr/bin/gs

RUN IPE_DONT_ENABLE=1 install-php-extensions \
    xdebug

# Install composer
COPY --link --from=composer:2 /usr/bin/composer /usr/local/bin/composer

# Base Configuration
COPY --link php/php.ini /usr/local/etc/php/conf.d/90-base.ini
COPY --link php/www.conf /usr/local/etc/php-fpm.d/www.conf

EXPOSE 9000
