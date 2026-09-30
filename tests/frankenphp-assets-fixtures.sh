#!/bin/sh
set -eu
mkdir -p "$1"
awk 'BEGIN { for (i = 0; i < 2000; i++) print ".asset-" i " { color: #123456; padding: 1rem; }" }' > "$1/test.css"
brotli -q 11 "$1/test.css"
zstd -q -19 "$1/test.css"
gzip -n -9 -c "$1/test.css" > "$1/test.css.gz"
