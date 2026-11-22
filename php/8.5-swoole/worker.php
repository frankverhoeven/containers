<?php

declare(strict_types=1);

use Symfony\Component\HttpFoundation\Request;

// Scope runtime selection to HTTP startup so bin/console keeps its normal runtime.
$workers = filter_var(
    getenv('SWOOLE_WORKERS') !== false ? getenv('SWOOLE_WORKERS') : 2,
    FILTER_VALIDATE_INT,
    ['options' => ['min_range' => 1]],
);
$maxRequests = filter_var(
    getenv('SWOOLE_MAX_REQUESTS') !== false ? getenv('SWOOLE_MAX_REQUESTS') : 1000,
    FILTER_VALIDATE_INT,
    ['options' => ['min_range' => 0]],
);
if ($workers === false || $maxRequests === false) {
    fwrite(STDERR, "SWOOLE_WORKERS must be positive; SWOOLE_MAX_REQUESTS must be nonnegative.\n");
    exit(1);
}

$entrypoint = '/app/public/index.php';
if (!is_file($entrypoint) || !is_file('/app/vendor/autoload_runtime.php')) {
    fwrite(STDERR, "Swoole requires /app/public/index.php and vendor/autoload_runtime.php.\n");
    exit(1);
}

// Register separately so authoritative application classmaps work. Requiring the
// app autoloader here would cause autoload_runtime.php to return prematurely.
spl_autoload_register(static function (string $class): void {
    $prefix = 'Runtime\\Swoole\\';
    if (!str_starts_with($class, $prefix)) {
        return;
    }
    $file = '/opt/swoole-runtime/src/' . str_replace('\\', '/', substr($class, strlen($prefix))) . '.php';
    if (!is_file($file)) {
        return;
    }
    // The app's autoloader is now registered. Trust only the local Caddy hop.
    if ($class === $prefix . 'Runtime' && class_exists(Request::class)) {
        Request::setTrustedProxies(
            array_unique([...Request::getTrustedProxies(), '127.0.0.1', '::1']),
            Request::getTrustedHeaderSet()
                | Request::HEADER_X_FORWARDED_FOR
                | Request::HEADER_X_FORWARDED_PROTO
                | Request::HEADER_X_FORWARDED_PORT,
        );
    }
    require $file;
}, true, true);
$_SERVER['APP_RUNTIME'] = $_ENV['APP_RUNTIME'] = 'Runtime\\Swoole\\Runtime';
// The runtime re-includes SCRIPT_FILENAME to obtain the application factory.
$_SERVER['SCRIPT_FILENAME'] = $entrypoint;
$_SERVER['SCRIPT_NAME'] = '/index.php';
$_SERVER['APP_RUNTIME_OPTIONS'] = array_replace_recursive(
    $_SERVER['APP_RUNTIME_OPTIONS'] ?? [],
    [
        'host' => '127.0.0.1',
        'port' => 8000,
        'settings' => [
            'worker_num' => $workers,
            'max_request' => $maxRequests,
            // Symfony's shared kernel and services require sequential requests per worker.
            'enable_coroutine' => false,
            'daemonize' => false,
            'pid_file' => '/tmp/swoole.pid',
        ],
    ],
);

require $entrypoint;
