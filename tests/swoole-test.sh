#!/bin/sh
set -eu
mkdir -p /app/config
printf '<?php\n' > /app/config/preload.php
php -v | grep "PHP ${PHP_VERSION:-8.5}"
for extension in bcmath exif excimer gd gmp igbinary imagick intl mbstring pcntl pdo_pgsql redis swoole uuid xsl zip; do
    # PHP expression, not shell expansion.
    # shellcheck disable=SC2016
    php -r 'exit(extension_loaded($argv[1]) ? 0 : 1);' "$extension"
done
php -r 'exit(extension_loaded("Zend OPcache") && !extension_loaded("xdebug") ? 0 : 1);'
composer --version
git --version
caddy list-modules | grep '^http.handlers.mercure$'
# An application with Symfony Runtime, without runtime/swoole in its vendor tree.
cd /app
composer require --no-interaction --no-progress --no-scripts --no-plugins \
    'symfony/runtime:^8.0' 'symfony/http-kernel:^8.0' 'symfony/service-contracts:^3.0'
# Generate autoload_runtime.php via the Symfony Composer plugin.
composer config allow-plugins.symfony/runtime true
composer dump-autoload --classmap-authoritative --no-interaction --no-scripts
sh /tests/swoole-http-test.sh
# Caddy startup errors must also stop the worker.
if start-swoole --config /does-not-exist > /tmp/missing-caddy.log 2>&1; then exit 1; fi
# Missing front controller must stop both services promptly.
rm /app/public/index.php
start-swoole > /tmp/missing-app.log 2>&1 &
pid=$!
sleep 2
if kill -0 "$pid" 2>/dev/null; then
    kill "$pid"
    echo 'Container survived a failed worker startup' >&2
    exit 1
fi
if wait "$pid"; then exit 1; fi
# CLI overrides must work without starting the HTTP services.
start-swoole php -r 'echo "CLI OK\n";' | grep 'CLI OK'
echo 'All Swoole tests passed'
