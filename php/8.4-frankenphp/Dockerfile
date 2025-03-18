FROM dunglas/frankenphp:php8.4

# Generic updates & dependencies
RUN set -eux \
    && apt-get update \
    && apt-get upgrade -y \
    && apt-get install -y \
        bash \
        git \
        openssh-client \
        unzip \
    && rm -rf /var/lib/apt/lists/*

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
    xdebug \

RUN \
	# Use "adduser -D ${USER}" for alpine based distros
	useradd www-data; \
	# Add additional capability to bind to port 80 and 443
	setcap CAP_NET_BIND_SERVICE=+eip /usr/local/bin/frankenphp; \
	# Give write access to /data/caddy and /config/caddy
	chown -R www-data:www-data /data/caddy && chown -R www-data:www-data /config/caddy

# Install composer
COPY --link --from=composer:2 /usr/bin/composer /usr/local/bin/composer

# Base Configuration
RUN cp $PHP_INI_DIR/php.ini-production $PHP_INI_DIR/php.ini
COPY --link php/8.4-frankenphp/php.ini /usr/local/etc/php/conf.d/90-base.ini
