FROM php:8.4-cli-bullseye

WORKDIR /var/www/html

# Generic updates & dependencies
RUN set -eux \
    && apt-get update \
    && apt-get upgrade -y \
    && apt-get install -y \
        bash \
        git \
        libcurl4-nss-dev \
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
    xsl \
    zip

RUN IPE_DONT_ENABLE=1 install-php-extensions \
    xdebug

# Install composer
COPY --link --from=composer:2 /usr/bin/composer /usr/local/bin/composer

# Base Configuration
COPY --link php/php.ini /usr/local/etc/php/conf.d/90-base.ini
