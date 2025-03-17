#!/bin/bash

while true; do
  echo "Starting Swoole server..."
  php /var/www/html/public/index.php &
  PID=$!

  fswatch -1 /var/www/html/

  echo "Changes detected, restarting..."
  kill -9 $PID
  sleep 1
done
