# GOYANA server (Laravel) dalam satu image: FrankenPHP = PHP 8.3 + web server Caddy dengan HTTPS otomatis.
# Dibangun dari folder repo:  docker compose -f deploy/docker/docker-compose.yml up -d --build
FROM dunglas/frankenphp:1-php8.3

RUN install-php-extensions pdo_mysql mbstring intl zip bcmath pcntl opcache @composer \
 && apt-get update && apt-get install -y --no-install-recommends python3 curl default-mysql-client \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /srv/goyana
COPY . /srv/goyana
RUN cd backend && rm -f .env && composer install --no-dev --prefer-dist --optimize-autoloader --no-interaction \
 && rm -rf storage && mkdir -p bootstrap/cache

COPY deploy/docker/Caddyfile /etc/caddy/Caddyfile
COPY deploy/docker/php.ini /usr/local/etc/php/conf.d/goyana.ini
COPY deploy/docker/entrypoint.sh /usr/local/bin/goyana-entrypoint
RUN chmod +x /usr/local/bin/goyana-entrypoint

ENTRYPOINT ["goyana-entrypoint"]
CMD ["frankenphp", "run", "--config", "/etc/caddy/Caddyfile"]
