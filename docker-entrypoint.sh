#!/bin/bash

#set -euo pipefail

ln -s /usr/bin/php7 /usr/bin/php
php -v

openssl req -x509 -nodes -days 365 -subj "/C=CA/ST=QC/O=SMG, Inc./CN=example.com" -addext "subjectAltName=DNS:example.com" -newkey rsa:2048 -keyout /certs/example.com.key -out /certs/example.com.crt;

export WAIT_HOSTS=wpforall_db:3306
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
define('WP_CACHE_KEY_SALT', 'localhost');
define( 'WP_DEBUG', true );
define( 'WP_DEBUG_LOG', true );
define( 'WP_HOME', 'http://localhost' );
define( 'WP_SITEURL', 'http://localhost' );
define( 'WP_MEMORY_LIMIT', '1024M' );
define( 'DISABLE_WP_CRON', true);
define('WP_CACHE', true);
define( 'RT_WP_NGINX_HELPER_CACHE_PATH', '/var/run/NGINX-cache' );" \
        ${ARGS}

    echo "Core Install"
    wp-cli core install \
        --url=http://${WORDPRESS_DOMAIN} \
        --title=${WORDPRESS_DOMAIN} \
        --admin_name=${WORDPRESS_ADMIN_USER:-admin} \
        --admin_password=${WORDPRESS_ADMIN_PASSWORD:-test} \
        --admin_email=${WORDPRESS_ADMIN_EMAIL} \
        --skip-email \
        ${ARGS}

    wp-cli language core install de_DE
    wp-cli site switch-language de_DE

    # Plugin Installation
    #wp-cli ${ARGS} plugin install https://downloads.wordpress.org/plugin/nginx-helper.2.2.2.zip
    #wp-cli ${ARGS} plugin activate nginx-helper
    #wp-cli ${ARGS} plugin install https://git-updater.com/wp-content/uploads/2021/07/git-updater-10.4.2.zip
    #wp-cli ${ARGS} plugin activate git-updater
    #wp-cli ${ARGS} plugin install https://github.com/elegantthemes/divi-extension-example/archive/refs/heads/master.zip
    #wp-cli ${ARGS} plugin activate divi-extension-example
    #wp-cli ${ARGS} plugin install https://github.com/nhutdm/wp-sync-db/archive/refs/heads/master.zip
    #wp-cli ${ARGS} plugin activate wp-sync-db

    # Theme Installation
    #mv /tmp/divi/ wp-content/themes/divi/

    #wp-cli ${ARGS} theme activate divi

    # Plugin DINSTALLATION
    wp-cli ${ARGS} plugin uninstall akismet
    wp-cli ${ARGS} plugin uninstall hello

    # Theme DINSTALLATION
    wp-cli ${ARGS} theme activate twentynineteen
    wp-cli ${ARGS} theme uninstall twentytwenty
    wp-cli ${ARGS} theme uninstall twentytwentyone

    #Set Options
    #p-cli ${ARGS} option update et_divi '{ "et_automatic_updates_options": { "username": "", "api_key": "" } }' --format=json

    #Set Rewriteurl
    wp-cli ${ARGS} rewrite structure '/%postname%/'

    chown -R www:www *
    chown -Rf www:www /var/lib/nginx

fi

exec "$@"
