FROM ubuntu as builder

RUN apt-get update
RUN apt-get install -y git curl

RUN echo "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
RUN echo "+                            OBACHT!                             +"
RUN echo "+    if plugins are updated use the option '--no-cache' while    +"
RUN echo "+    building the image. otherwise the intermediate cache of     +"
RUN echo "+    git clone will be used                                      +"
RUN echo "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"

FROM alpine:edge

RUN apk add --no-cache nginx-mod-http-perl

RUN apk --update add ca-certificates && /usr/sbin/update-ca-certificates

RUN apk update
RUN apk upgrade
RUN apk add --update bash tzdata mysql-client
RUN apk add supervisor curl nginx zip --no-cache
RUN apk add icu-dev
RUN apk add php7 \
	    php7-dev \
	    php7-cli \
		libjpeg-turbo-dev \
		build-base \
		libpng-dev \
		libxml2-dev \
		libzip-dev \
		openssh-client \
		php7-fpm \
		php7-mbstring \
		php7-curl \
		php7-phar \
		php7-zip \
		php7-mcrypt \
		php7-session \
		php7-soap \
		php7-sockets \
		php7-ftp \
		php7-openssl \
		php7-json \
		php7-dom \
		php7-xml \
		php7-mysqli \
		php7-simplexml \
		php7-pdo \
		php7-pdo_mysql \
		php7-zip \
		php7-mysqli \
		php7-apcu \
		php7-gd \
		php7-gettext \
		php7-xmlreader \
		php7-iconv \
		php7-curl \
		php7-tokenizer \
	    php7-pear \
	    php7-bcmath \
	    php7-redis \
		imagemagick \
		imagemagick-libs \
		imagemagick-dev \
		php7-imagick \
		php7-pcntl \
        php7-opcache \
		php7-zip \
		sqlite \
		ghostscript \
		vim \
		php7-ctype && \
	adduser -D -g 'www' www && \
	mkdir /www && \
	rm -rf /var/cache/apk/*

# PHPINI dependencies
RUN echo "file_uploads = On" >> /etc/php7/php.ini \
    && echo "memory_limit = 512M" >> /etc/php7/php.ini \
    && echo "upload_max_filesize = 512M" >> /etc/php7/php.ini \
    && echo "post_max_size = 512M" >> /etc/php7/php.ini \
    && echo "max_execution_time = 600" >> /etc/php7/php.ini \
    && echo "max_input_vars = 3000" >> /etc/php7/php.ini \
    && echo "zlib.output_compression=0" >> /etc/php7/php.ini \
    && echo "max_input_vars = 3000" >> /etc/php7/php.ini \
    && echo "zlib.output_compression_level=9" >> /etc/php7/php.ini

# SETUP PHP-FPM CONFIG SETTINGS (max_children / max_requests)
#RUN echo 'pm.max_children = 50' >> /etc/php-fpm.d/zz-docker.conf && \
#    echo 'pm.max_requests = 500' >> /etc/php-fpm.d/zz-docker.conf

# SETUP XDebug in php.ini
RUN apk add php7-xdebug --repository http://dl-3.alpinelinux.org/alpine/edge/testing/
RUN echo "zend_extension=/usr/lib/php7/modules/xdebug.so" >> /etc/php7/conf.d/xdebug.ini \
    && echo "xdebug.mode=debug" >> /etc/php7/conf.d/xdebug.ini \
    && echo "xdebug.log=/tmp/xdebug.log" >> /etc/php7/conf.d/xdebug.ini \
    && echo "xdebug.discover_client_host =1" >> /etc/php7/conf.d/xdebug.ini \
    && echo "xdebug.start_with_request=yes" >> /etc/php7/conf.d/xdebug.ini \
    && echo "xdebug.log_level = 7" >> /etc/php7/conf.d/xdebug.ini \
    && echo "xdebug.idekey=PHPSTORM" >> /etc/php7/conf.d/xdebug.ini \
    && echo "xdebug.client_host=host.docker.internal" >> /etc/php7/conf.d/xdebug.ini \
    && touch /tmp/xdebug.log \
    && chown www:www /tmp/xdebug.log \
    && chmod 666 /tmp/xdebug.log

RUN export XDEBUG_SESSION=1

# setup redis
RUN apk --update add redis
RUN echo "vm.overcommit_memory = 1" >> /etc/sysctl.conf

# set recommended PHP.ini settings
# see https://secure.php.net/manual/en/opcache.installation.php
RUN set -eux; \
 	{ \
 		echo 'opcache.memory_consumption=128'; \
		echo 'opcache.interned_strings_buffer=8'; \
 		echo 'opcache.max_accelerated_files=4000'; \
 		echo 'opcache.revalidate_freq=2'; \
 		echo 'opcache.fast_shutdown=1'; \
	} > /etc/php7/conf.d/opcache-recommended.ini

# https://www.php.net/manual/en/errorfunc.constants.php
# https://github.com/docker-library/wordpress/issues/420#issuecomment-517839670
RUN { \
		echo 'error_reporting = E_ERROR | E_WARNING | E_PARSE | E_CORE_ERROR | E_CORE_WARNING | E_COMPILE_ERROR | E_COMPILE_WARNING | E_RECOVERABLE_ERROR'; \
		echo 'display_errors = Off'; \
		echo 'display_startup_errors = Off'; \
		echo 'log_errors = On'; \
		echo 'error_log = /dev/stderr'; \
		echo 'log_errors_max_len = 1024'; \
		echo 'ignore_repeated_errors = On'; \
		echo 'ignore_repeated_source = Off'; \
		echo 'html_errors = Off'; \
	} > /etc/php7/conf.d/error-logging.ini

WORKDIR /www

# nginx configuration
COPY ./etc/nginx.conf /etc/nginx/nginx.conf
COPY ./etc/php-fpm.conf /etc/php7/php-fpm.conf
COPY ./etc/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Add WP-CLI
ADD https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar /usr/local/bin/wp-cli
RUN chmod +x /usr/local/bin/wp-cli

# add WAIT
ENV WAIT_VERSION 2.7.2
ADD https://github.com/ufoscout/docker-compose-wait/releases/download/$WAIT_VERSION/wait /wait
RUN chmod +x /wait

#Forward Message to mailhog
RUN curl --location --output /usr/local/bin/mhsendmail https://github.com/mailhog/mhsendmail/releases/download/v0.2.0/mhsendmail_linux_amd64 \
    && chmod +x /usr/local/bin/mhsendmail \
    && echo 'sendmail_path="/usr/local/bin/mhsendmail --smtp-addr=mailhog:1025 --from=no-reply@gbp.lo"' > /etc/php7/conf.d/mailhog.ini

# Change TimeZone
RUN apk add --update tzdata
ENV TZ=Europe/Berlin

RUN apk update && \
    apk add --no-cache openssl && \
    rm -rf "/var/cache/apk/*"

# for PHP FPM gives permission denied reason
RUN chown -Rf www:www /var/lib/nginx

COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh

ENTRYPOINT ["docker-entrypoint.sh"]

CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]