#!/bin/sh
set -eu
# An HTTP probe exercises a worker as well as checking the Caddy admin endpoint.
# Accept application errors/redirects: apps need not define a dedicated route.
curl -fsS --max-time 3 http://127.0.0.1:2019/metrics >/dev/null
curl -sS --max-time 3 -o /dev/null http://127.0.0.1:8000/
