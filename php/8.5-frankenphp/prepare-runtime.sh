#!/bin/sh
set -eu

# Keep runtime libraries and ImageMagick delegates. Do not use autoremove:
# PHP extensions and their dlopened libraries are not represented in apt deps.
packages=$(dpkg-query -W -f='${binary:Package}\n' | sed 's/:.*//' | awk '
    /^(gcc|g[+][+]|cpp)(-|$)/ && !/-base$/ { print; next }
    /^binutils/ { print; next }
    /^lib(gcc|stdc[+][+])-[0-9]+-dev$/ { print; next }
    /^(autoconf|automake|dpkg-dev|libdpkg-perl|libc6-dev|libc-dev-bin|linux-libc-dev|libcrypt-dev|make|m4|pkg-config|pkgconf|pkgconf-bin|re2c|git|git-man|openssh-client|unzip|brotli|zstd)$/ { print }
')
if [ -n "$packages" ]; then
    # Intentional word splitting: the list contains package names only.
    apt-get purge -y $packages
fi
apt-get clean
rm -rf /var/lib/apt/lists/* /var/cache/apt/* /usr/src /usr/include \
    /usr/local/include /usr/local/lib/php/build /usr/local/lib/php/PEAR \
    /usr/local/lib/php/Archive /usr/local/lib/php/Console \
    /usr/local/lib/php/OS /usr/local/lib/php/Structures \
    /usr/local/lib/php/XML /composer /root/.cache /tmp/*
rm -f /usr/local/bin/composer /usr/local/bin/php-cgi /usr/local/bin/phpdbg \
    /usr/local/bin/phpize /usr/local/bin/php-config /usr/local/bin/pear \
    /usr/local/bin/peardev /usr/local/bin/pecl /usr/local/bin/phar* \
    /usr/local/bin/docker-php-source /usr/local/bin/docker-php-ext-* \
    /usr/local/bin/install-php-extensions /usr/local/bin/prepare-runtime \
    /usr/local/lib/php/.channels/* /usr/local/lib/php/.registry/* \
    /usr/local/lib/php/PEAR.php /usr/local/lib/php/PEAR5.php \
    /usr/local/lib/php/System.php /usr/local/etc/php/conf.d/99-dev.ini.disabled
find /usr/local/lib/php/extensions -name '*xdebug*' -delete
# Fail the build if package removal broke a binary or PHP extension.
find /usr/local/bin /usr/local/lib -type f \( -name '*.so' -o -perm /111 \) \
    -exec ldd '{}' ';' > /tmp/runtime-libraries.txt 2>&1
if grep -q 'not found' /tmp/runtime-libraries.txt; then
    cat /tmp/runtime-libraries.txt
    exit 1
fi
rm /tmp/runtime-libraries.txt
setcap cap_net_bind_service=+ep /usr/local/bin/frankenphp
php -d opcache.preload= -v
