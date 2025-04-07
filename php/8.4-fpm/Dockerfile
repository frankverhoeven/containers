FROM php:8.4-fpm-bullseye

WORKDIR /var/www/html

# Generic updates & dependencies
RUN set -eux \
    && apt-get update \
    && apt-get upgrade -y \
    && apt-get install -y \
        bash \
        git \
        libfcgi-bin \
        openssh-client \
        unzip \
    && rm -rf /var/lib/apt/lists/*

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
    pdo_mysql \
    pdo_pgsql \
    redis \
    uuid \
    xsl \
    zip

RUN IPE_DONT_ENABLE=1 install-php-extensions \
    xdebug

# Install composer
COPY --link --from=composer:2 /usr/bin/composer /usr/local/bin/composer
ENV COMPOSER_CACHE_DIR = "/composer/cache"

# Base Configuration
RUN cp $PHP_INI_DIR/php.ini-production $PHP_INI_DIR/php.ini
COPY --link php/php.ini /usr/local/etc/php/conf.d/90-base.ini
COPY --link php/www.conf /usr/local/etc/php-fpm.d/www.conf

EXPOSE 9000
