#!/usr/bin/env bash
set -eu

# Keep the official PHP image's command override behavior for CLI/build tasks.
if [[ $# -gt 0 && "$1" != -* ]]; then
    exec docker-php-entrypoint "$@"
fi

if [[ $# == 0 ]]; then
    set -- --config /etc/caddy/Caddyfile --adapter caddyfile
fi

php /usr/local/lib/swoole-worker.php &
worker_pid=$!
caddy run "$@" &
caddy_pid=$!
# Invoked through the EXIT trap.
# shellcheck disable=SC2329
cleanup() {
    trap '' TERM INT
    kill -TERM "$worker_pid" "$caddy_pid" 2>/dev/null || true
    wait "$worker_pid" 2>/dev/null || true
    wait "$caddy_pid" 2>/dev/null || true
}
trap cleanup EXIT
trap 'exit 0' TERM INT

# Stop the whole container if either server exits, even after a successful exit.
set +e
wait -n "$worker_pid" "$caddy_pid"
status=$?
set -e
if [[ "$status" == 0 ]]; then status=1; fi
exit "$status"
