FROM php:8.4-cli-bullseye

WORKDIR /var/www/html

# Generic updates & dependencies
RUN set -eux \
    && apt-get update \
    && apt-get upgrade -y \
    && apt-get install -y \
        bash \
        fswatch \
        git \
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
    swoole \
    xdebug

# Install composer
COPY --link --from=composer:2 /usr/bin/composer /usr/local/bin/composer

# Base Configuration
RUN cp $PHP_INI_DIR/php.ini-production $PHP_INI_DIR/php.ini
COPY --link php/php.ini /usr/local/etc/php/conf.d/90-base.ini
COPY --link php/8.4-cli/swoole-dev-server.sh /usr/local/bin/swoole-dev-server.sh
RUN chmod +x /usr/local/bin/swoole-dev-server.sh

# Swoole:
# RUN docker-php-ext-enable-xdebug
#
# To run swoole in dev with reloading
# CMD ["swoole-dev-server.sh"]
#
# To run swoole on prod
# CMD ["php", "/var/www/html/public/index.php"]
