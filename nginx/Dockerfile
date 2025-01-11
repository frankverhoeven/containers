FROM nginx:1.27-alpine

# Working directory
WORKDIR /var/www/html

# Generic updates & dependencies
RUN set -eux \
    && apk update \
    && apk upgrade \
    && rm -rf /var/cache/apk/*

# Default configuration
COPY --link nginx/cloudflare /etc/nginx/cloudflare
COPY --link nginx/nginx.conf /etc/nginx/nginx.conf
COPY --link nginx/conf.d/ /etc/nginx/conf.d/

EXPOSE 80
