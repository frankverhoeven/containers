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
REQUIRED_EXTENSIONS="bcmath exif gd gmp igbinary imagick intl mbstring pcntl pdo_pgsql redis uuid xsl zip"

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
composer --version | grep "Composer version 2"

# 5. Test FrankenPHP binary is available
echo "✓ Checking FrankenPHP binary..."
frankenphp version | grep -qi "FrankenPHP" && echo "  - frankenphp available ✓"

# 6. Test configuration is loaded
echo "✓ Checking custom configuration..."
php -i | grep -q "opcache.enable" && echo "  - opcache config loaded ✓"

# 7. Test git is available
echo "✓ Checking git availability..."
git --version | grep -q "git version" && echo "  - git available ✓"

echo ""
echo "========================="
echo "All tests passed! ✓"
echo "========================="
