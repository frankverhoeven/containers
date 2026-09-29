#!/usr/bin/env sh
set -eu

echo "✓ Checking static asset serving..."
test_dir=$(mktemp -d)
server_pid=
cleanup() {
    if [ -n "$server_pid" ]; then
        kill "$server_pid" 2>/dev/null || true
        wait "$server_pid" 2>/dev/null || true
    fi
    rm -rf "$test_dir"
}
trap cleanup EXIT
trap 'exit 1' HUP INT TERM

mkdir -p /app/public/assets
awk 'BEGIN { for (i = 0; i < 2000; i++) print ".asset-" i " { color: #123456; padding: 1rem; }" }' > /app/public/assets/test.css
cp /app/public/assets/test.css /app/public/assets/fallback.css
brotli -q 11 /app/public/assets/test.css
zstd -q -19 /app/public/assets/test.css
gzip -n -9 -c /app/public/assets/test.css > /app/public/assets/test.css.gz
cat > /app/public/index.php <<'PHP'
<?php
while (frankenphp_handle_request(static function (): void {
    header('Content-Type: text/plain');
    header('Cache-Control: private, no-store');
    echo 'PHP fallback';
})) {}
PHP
echo '<?php echo "must stay hidden";' > /app/public/secret.php
for extension in br zst gz; do
    cp /app/public/secret.php "/app/public/secret.php.$extension"
done

export SERVER_NAME=http://127.0.0.1:8080
export CADDY_GLOBAL_OPTIONS='admin off'
export FRANKENPHP_CONFIG='num_threads 2'
export FRANKENPHP_WORKER_CONFIG='num 1'
frankenphp validate --config /etc/frankenphp/Caddyfile
frankenphp run --config /etc/frankenphp/Caddyfile > "$test_dir/server.log" 2>&1 &
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
! grep -qi '^Content-Encoding:' "$test_dir/headers"
cmp "$test_dir/body" /app/public/assets/test.css
! grep -qi '^Cache-Control:' "$test_dir/headers"
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
    assert_header '^Cache-Control: private, no-store'
    test "$(cat "$test_dir/body")" = 'PHP fallback'
done
for path in /secret.php /secret.php.br /secret.php.zst /secret.php.gz; do
    status=$(curl -sS -o /dev/null -w '%{http_code}' "$SERVER_NAME$path")
    test "$status" = 404
done
status=$(curl -sS -o /dev/null -w '%{http_code}' "$SERVER_NAME/.well-known/mercure")
test "$status" = 404
echo "  - negotiation, validators, ranges, HEAD, live compression and PHP routing ✓"
