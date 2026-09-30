#!/usr/bin/env sh
set -e

echo "========================="
echo "Testing FrankenPHP Image..."
echo "========================="
echo ""

# Setup: Create dummy preload file (referenced in php.ini)
mkdir -p /app/config
echo "<?php // Dummy preload file for testing" > /app/config/preload.php

# 1. PHP version check
echo "✓ Checking PHP version..."
php -v | grep "PHP 8.5"

# 2. Verify all required extensions are loaded
echo "✓ Checking required extensions..."
REQUIRED_EXTENSIONS="bcmath exif excimer gd gmp igbinary imagick intl mbstring pcntl pdo_pgsql redis uuid xsl zip"

for ext in $REQUIRED_EXTENSIONS; do
    if php -m | grep -qi "^${ext}$"; then
        echo "  - ${ext}: installed"
    else
        echo "  - ${ext}: MISSING"
        exit 1
    fi
done

# Check opcache separately (appears as "Zend OPcache")
if php -m | grep -qi "opcache"; then
    echo "  - opcache: installed"
else
    echo "  - opcache: MISSING"
    exit 1
fi

# 3. Verify xdebug is installed but not enabled
echo "✓ Checking xdebug (should be installed but disabled)..."
if php -r "echo extension_loaded('xdebug') ? 'enabled' : 'disabled';" | grep -q "disabled"; then
    echo "  - xdebug: installed but disabled ✓"
else
    echo "  - xdebug: ERROR - should be disabled by default"
    exit 1
fi

# 4. Test Composer is working
echo "✓ Checking Composer..."
if [ "${IMAGE_VARIANT:-dev}" = runtime ]; then
    for tool in composer git gcc g++ phpize phpdbg php-cgi brotli zstd ssh; do
        if command -v "$tool" >/dev/null 2>&1; then
            echo "Build tool unexpectedly present: $tool" >&2
            exit 1
        fi
    done
    test -z "$(find /usr/local/lib/php/extensions -name '*xdebug*')"
else
    composer --version | grep "Composer version 2"
fi

# 5. Test FrankenPHP binary is available
echo "✓ Checking FrankenPHP binary..."
frankenphp version | grep -qi "FrankenPHP" && echo "  - frankenphp available ✓"

# 6. Test configuration is loaded
echo "✓ Checking custom configuration..."
php -i | grep -q "opcache.enable" && echo "  - opcache config loaded ✓"

# 7. Test git is available
echo "✓ Checking git availability..."
if [ "${IMAGE_VARIANT:-dev}" != runtime ]; then
    git --version | grep -q "git version"
    docker-php-ext-enable xdebug
    php -r 'exit(extension_loaded("xdebug") ? 0 : 1);'
    rm -f /usr/local/etc/php/conf.d/*xdebug*.ini
fi

test -s /etc/ssl/certs/ca-certificates.crt
getcap /usr/local/bin/frankenphp | grep -q 'cap_net_bind_service=ep'

# Exercise dynamic image delegates and timezone data, not just extension loading.
php -r '$i = new Imagick(); $i->newImage(10, 10, "red"); $i->setImageFormat("png"); $png = $i->getImagesBlob(); $j = new Imagick(); $j->readImageBlob($png); $j->resizeImage(5, 5, Imagick::FILTER_LANCZOS, 1); if ($j->getImageWidth() !== 5) { exit(1); }'
php -r '$d = new DateTimeImmutable("2026-07-01", new DateTimeZone("Europe/Amsterdam")); exit($d->format("P") === "+02:00" ? 0 : 1);'
find /usr/local/bin /usr/local/lib -type f \( -name '*.so' -o -perm /111 \) -exec ldd '{}' ';' > /tmp/test-libraries.txt 2>&1
if grep -q 'not found' /tmp/test-libraries.txt; then
    cat /tmp/test-libraries.txt
    exit 1
fi

# 8. Exercise the actual Caddyfile over HTTP, including compressed sidecars.
sh /tests/frankenphp-assets-test.sh

echo ""
echo "========================="
echo "All tests passed! ✓"
echo "========================="
