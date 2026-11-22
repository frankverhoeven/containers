#!/usr/bin/env sh
set -eu

echo "✓ Checking static asset serving..."
test_dir=$(mktemp -d)
server_pid=
cleanup() {
    result=$?
    if [ "$result" -ne 0 ] && [ -f "$test_dir/server.log" ]; then cat "$test_dir/server.log"; fi
    if [ -n "$server_pid" ]; then
        kill "$server_pid" 2>/dev/null || true
        wait "$server_pid" 2>/dev/null || true
    fi
    rm -rf "$test_dir"
}
trap cleanup EXIT
trap 'exit 1' HUP INT TERM

mkdir -p /app/public/assets
if [ -d /fixtures ]; then
    cp /fixtures/test.css* /app/public/assets/
else
    sh /tests/frankenphp-assets-fixtures.sh /app/public/assets
fi
cp /app/public/assets/test.css /app/public/assets/fallback.css
cp /tests/swoole-fixture.php /app/public/index.php
echo '<?php echo "must stay hidden";' > /app/public/secret.php
for extension in br zst gz; do
    cp /app/public/secret.php "/app/public/secret.php.$extension"
done

export SERVER_NAME=http://127.0.0.1:8080
export CADDY_GLOBAL_OPTIONS=''
export SWOOLE_WORKERS=1
export SWOOLE_MAX_REQUESTS=0
caddy validate --config /etc/caddy/Caddyfile
start-swoole > "$test_dir/server.log" 2>&1 &
server_pid=$!

attempt=0
until curl -fsS "$SERVER_NAME/assets/test.css" -o /dev/null 2>/dev/null; do
    attempt=$((attempt + 1))
    if [ "$attempt" -ge 50 ] || ! kill -0 "$server_pid" 2>/dev/null; then
        cat "$test_dir/server.log"
        exit 1
    fi
    sleep 0.1
done

request() {
    curl -fsS -D "$test_dir/headers" -o "$test_dir/body" "$@"
}
assert_header() {
    if ! grep -Eiq "$1" "$test_dir/headers"; then
        cat "$test_dir/headers"
        echo "Missing expected header: $1" >&2
        exit 1
    fi
}

# Byte equality proves the server used the build artifact, not live encoding.
for encoding in br zstd gzip; do
    case "$encoding" in
        br) extension=br ;;
        zstd) extension=zst ;;
        gzip) extension=gz ;;
    esac
    request -H "Accept-Encoding: $encoding" "$SERVER_NAME/assets/test.css"
    assert_header "^Content-Encoding: $encoding"
    assert_header '^Content-Type: text/css'
    assert_header '^Vary:.*Accept-Encoding'
    cmp "$test_dir/body" "/app/public/assets/test.css.$extension"
    echo "  - $encoding sidecar served verbatim ✓"
done

request -H 'Accept-Encoding: br, zstd, gzip' "$SERVER_NAME/assets/test.css"
assert_header '^Content-Encoding: br'
request -H 'Accept-Encoding: br;q=0.5, gzip;q=1' "$SERVER_NAME/assets/test.css"
assert_header '^Content-Encoding: gzip'

# Identity responses, including clients explicitly rejecting all encodings.
request -H 'Accept-Encoding: br;q=0, zstd;q=0, gzip;q=0' "$SERVER_NAME/assets/test.css"
if grep -qi '^Content-Encoding:' "$test_dir/headers"; then exit 1; fi
cmp "$test_dir/body" /app/public/assets/test.css
if grep -qi '^Cache-Control:' "$test_dir/headers"; then exit 1; fi
assert_header '^Last-Modified:'
etag=$(sed -n 's/^[Ee][Tt][Aa][Gg]: *//p' "$test_dir/headers" | tr -d '\r')
test -n "$etag"
request -H "If-None-Match: $etag" "$SERVER_NAME/assets/test.css"
assert_header '^HTTP/1.1 304'
request -H 'Accept-Encoding: br' "$SERVER_NAME/assets/test.css"
etag=$(sed -n 's/^[Ee][Tt][Aa][Gg]: *//p' "$test_dir/headers" | tr -d '\r')
request -H 'Accept-Encoding: br' -H "If-None-Match: $etag" "$SERVER_NAME/assets/test.css"
assert_header '^HTTP/1.1 304'

request -H 'Accept-Encoding: identity' -H 'Range: bytes=0-9' "$SERVER_NAME/assets/test.css"
assert_header '^HTTP/1.1 206'
test "$(wc -c < "$test_dir/body" | tr -d ' ')" -eq 10
request -I -H 'Accept-Encoding: br' "$SERVER_NAME/assets/test.css"
assert_header '^Content-Encoding: br'

# No sidecars: live gzip still works and returns the original content.
request -H 'Accept-Encoding: gzip' "$SERVER_NAME/assets/fallback.css"
assert_header '^Content-Encoding: gzip'
gzip -dc "$test_dir/body" > "$test_dir/decoded"
cmp "$test_dir/decoded" /app/public/assets/fallback.css
request "$SERVER_NAME/assets/fallback.css"
cmp "$test_dir/body" /app/public/assets/fallback.css

for path in /application-route /assets/missing.css; do
    request "$SERVER_NAME$path"
    assert_header '^Cache-Control: (private, no-store|no-store, private)'
    test "$(cat "$test_dir/body")" = 'PHP fallback'
done
for path in /secret.php /secret.php.br /secret.php.zst /secret.php.gz; do
    status=$(curl -sS -o /dev/null -w '%{http_code}' "$SERVER_NAME$path")
    test "$status" = 404
done
status=$(curl -sS -o /dev/null -w '%{http_code}' "$SERVER_NAME/.well-known/mercure")
test "$status" = 404
echo "  - negotiation, validators, ranges, HEAD, live compression and PHP routing ✓"

# The same application instance serves repeated requests and terminates each one.
request "$SERVER_NAME/state?first=1"
assert_header '^X-Request-Uri: /state\?first=1'
assert_header '^Set-Cookie: first=1'
assert_header '^Set-Cookie: second=2'
assert_header '^X-Multi: one'
assert_header '^X-Multi: two'
http_worker_pid=$(sed -n 's/^[Xx]-[Ww]orker-[Pp]id: *//p' "$test_dir/headers" | tr -d '\r')
requests=$(sed -n 's/^[Xx]-[Ww]orker-[Rr]equests: *//p' "$test_dir/headers" | tr -d '\r')
request -X POST --data 'payload' "$SERVER_NAME/state?second=2"
assert_header "^X-Worker-Pid: $http_worker_pid"
assert_header "^X-Worker-Requests: $((requests + 1))"
assert_header "^X-Terminated: $requests"
assert_header '^X-Request-Method: POST'
assert_header '^X-Request-Body: payload'
assert_header '^X-Request-Uri: /state\?second=2'
# Request data must not leak into the next request.
request "$SERVER_NAME/clean"
assert_header '^X-Request-Method: GET'
assert_header '^X-Scheme: http'
# Caddy must discard spoofed forwarding headers from an untrusted client.
request -H 'X-Forwarded-For: 203.0.113.123' -H 'X-Forwarded-Proto: https' "$SERVER_NAME/clean"
assert_header '^X-Client-Ip: 127.0.0.1'
assert_header '^X-Scheme: http'
assert_header '^X-Request-Uri: /clean'
# Sessions persist for the same cookie and stay isolated for another client.
request -c "$test_dir/cookies" "$SERVER_NAME/session"
test "$(cat "$test_dir/body")" = 1
assert_header '^Set-Cookie:'
request -b "$test_dir/cookies" "$SERVER_NAME/session"
test "$(cat "$test_dir/body")" = 2
request "$SERVER_NAME/session"
test "$(cat "$test_dir/body")" = 1
swoole-healthcheck
# If the Swoole master exits, the supervisor must also stop Caddy.
kill -TERM "$(cat /tmp/swoole.pid)"
attempt=0
while kill -0 "$server_pid" 2>/dev/null; do
    attempt=$((attempt + 1))
    if [ "$attempt" -ge 50 ]; then
        cat "$test_dir/server.log"
        echo 'Supervisor survived worker exit' >&2
        exit 1
    fi
    sleep 0.1
done
if wait "$server_pid"; then exit 1; fi
server_pid=
if swoole-healthcheck 2>/dev/null; then exit 1; fi
