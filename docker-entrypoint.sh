#!/bin/bash

ln -s /usr/bin/php7 /usr/bin/php
php -v

openssl req -x509 -nodes -days 365 -subj "/C=CA/ST=QC/O=SASOM, Inc./CN=${WORDPRESS_DOMAIN}" -addext "subjectAltName=DNS:${WORDPRESS_DOMAIN}" -newkey rsa:2048 -keyout /certs/${WORDPRESS_DOMAIN}.key -out /certs/${WORDPRESS_DOMAIN}.crt;

export WAIT_HOSTS=${WORDPRESS_DB_HOST}:3306
export WAIT_HOSTS_TIMEOUT=30
export WAIT_BEFORE_HOSTS=5
export WAIT_AFTER_HOSTS=5
/wait

if [ ! -f "wp-config.php" ]; then
    ARGS="--allow-root"

    echo "Core Download"
    wp-cli core download --locale=de_DE

    echo "Config Create"
    wp-cli config create \
        --dbhost=${WORDPRESS_DB_HOST} \
        --dbname=${WORDPRESS_DB_NAME} \
        --dbuser=${WORDPRESS_DB_USER} \
        --dbpass=${WORDPRESS_DB_PASSWORD} \
        --extra-php="
/** Local Development */
define('WP_CACHE_KEY_SALT', '${WORDPRESS_DOMAIN}');
define( 'WP_DEBUG', true );
define( 'WP_DEBUG_LOG', true );
define( 'WP_HOME', 'https://${WORDPRESS_DOMAIN}' );
define( 'WP_SITEURL', 'https://${WORDPRESS_DOMAIN}' );
define( 'WP_MEMORY_LIMIT', '1024M' );
define( 'DISABLE_WP_CRON', true);
define( 'WP_CACHE', true);
define( 'RT_WP_NGINX_HELPER_CACHE_PATH', '/var/run/NGINX-cache' );
define( 'WP_REDIS_HOST', '192.168.32.3' );
define( 'WP_REDIS_PORT', 6379 );
define( 'WP_REDIS_PASSWORD', 'redispass' );
define( 'WP_REDIS_TIMEOUT', 1 );
define( 'WP_REDIS_READ_TIMEOUT', 1 );
define( 'WP_REDIS_DATABASE', 0 );" \
${ARGS}

    echo "Core Install"
    wp-cli core install \
        --url=https://${WORDPRESS_DOMAIN} \
        --title=${WORDPRESS_DOMAIN} \
        --admin_name=${WORDPRESS_ADMIN_USER:-admin} \
        --admin_password=${WORDPRESS_ADMIN_PASSWORD:-test} \
        --admin_email=${WORDPRESS_ADMIN_EMAIL} \
        --skip-email \
        ${ARGS}

    wp-cli language core install de_DE
    wp-cli site switch-language de_DE

    # Plugin Installation
    wp-cli ${ARGS} plugin install https://downloads.wordpress.org/plugin/nginx-helper.2.2.2.zip
    wp-cli ${ARGS} plugin activate nginx-helper
    wp-cli ${ARGS} plugin install https://downloads.wordpress.org/plugin/redis-cache.2.0.22.zip
    wp-cli ${ARGS} plugin activate redis-cache
    wp-cli ${ARGS} plugin install https://downloads.wordpress.org/plugin/query-monitor.3.7.1.zip
    wp-cli ${ARGS} plugin activate query-monitor
    wp-cli ${ARGS} plugin install https://downloads.wordpress.org/plugin/flush-opcache.4.1.2.zip
    wp-cli ${ARGS} plugin activate flush-opcache
    wp-cli ${ARGS} plugin install https://downloads.wordpress.org/plugin/updraftplus.1.16.65.zip
    wp-cli ${ARGS} plugin activate updraftplus

    # Remove Plugin's
    wp-cli ${ARGS} plugin uninstall akismet
    wp-cli ${ARGS} plugin uninstall hello

    # Remove Theme's
    wp-cli ${ARGS} theme activate twentynineteen
    wp-cli ${ARGS} theme uninstall twentytwenty
    wp-cli ${ARGS} theme uninstall twentytwentyone

    #Set Rewrite url
    wp-cli ${ARGS} rewrite structure '/%postname%/'

    chown -R www:www *
    chown -Rf www:www /var/lib/nginx

fi

exec "$@"
