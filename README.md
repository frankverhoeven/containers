# Base Images

## PHP

**compose.yaml**
```yaml
services:
    php:
        image: ghcr.io/frankverhoeven/php-8.4-fpm
```

**Dockerfile**
```Dockerfile
FROM ghcr.io/frankverhoeven/php-8.4-fpm
```

### Development INI
```Dockerfile
RUN mv /usr/local/etc/php/conf.d/99-dev.ini.disabled /usr/local/etc/php/conf.d/99-dev.ini
```

If using `APP_DEBUG` (Symfony) env vars you could use:

```Dockerfile
RUN if [ "${APP_DEBUG}" = "1" ]; then \
        mv /usr/local/etc/php/conf.d/99-dev.ini.disabled /usr/local/etc/php/conf.d/99-dev.ini; \
    fi
```

### Healthcheck
```yaml
services:
    php:
        healthcheck:
            test: "SCRIPT_NAME=/ping SCRIPT_FILENAME=/ping REQUEST_METHOD=GET cgi-fcgi -bind -connect 127.0.0.1:9000 | grep 'pong' || exit 1"
            start_period: 10s
            interval: 30s
            timeout: 10s
            retries: 3
```
