FROM alpine:3.5
MAINTAINER Andre Bazaglia <abazaglia@gmail.com>

ENV TIMEZONE=America/Sao_Paulo \
    PHP_MEMORY_LIMIT=128M MAX_UPLOAD=8M PHP_MAX_FILE_UPLOAD=8M PHP_MAX_POST=8M \
    NGINX_VERSION=1.12.0

# let's roll
RUN	apk update && \
    apk upgrade && \
    apk add tzdata && \
    ln -snf /usr/share/zoneinfo/${TIMEZONE} /etc/localtime && echo ${TIMEZONE} > /etc/timezone && \
    apk add --update \
    bash curl git ca-certificates nginx php7 \
    php7-fpm php7-json php7-zlib php7-xml php7-mysqli php7-pdo php7-pdo_mysql php7-phar php7-curl php7-openssl \
    php7-dom php7-intl php7-gd php7-ctype php7-opcache php7-apcu \
    php7-mcrypt php7-mbstring php7-session php7-zip && \
    sed -i "s|;*daemonize =.*|daemonize = yes|i" /etc/php7/php-fpm.conf && \
    sed -i "s|;*clear_env =.*|clear_env = no|i" /etc/php7/php-fpm.d/www.conf && \
    sed -i "s|;*listen\s*=\s*127.0.0.1:9000|listen = 9000|g" /etc/php7/php-fpm.conf && \
    sed -i "s|;*listen\s*=\s*/||g" /etc/php7/php-fpm.conf && \
    sed -i "s|;*date.timezone =.*|date.timezone = ${TIMEZONE}|i" /etc/php7/php.ini && \
    sed -i "s|;*memory_limit =.*|memory_limit = ${PHP_MEMORY_LIMIT}|i" /etc/php7/php.ini && \
    sed -i "s|;*upload_max_filesize =.*|upload_max_filesize = ${MAX_UPLOAD}|i" /etc/php7/php.ini && \
    sed -i "s|;*max_file_uploads =.*|max_file_uploads = ${PHP_MAX_FILE_UPLOAD}|i" /etc/php7/php.ini && \
    sed -i "s|;*post_max_size =.*|post_max_size = ${PHP_MAX_POST}|i" /etc/php7/php.ini && \
    sed -i "s|;*cgi.fix_pathinfo=.*|cgi.fix_pathinfo= 0|i" /etc/php7/php.ini && \
    apk del tzdata && \
    rm -rf /var/cache/apk/* && \
    ln -s /usr/bin/php7 /usr/bin/php && \
    ln -sf /dev/stdout /var/log/nginx/access.log && \
    ln -sf /dev/stderr /var/log/nginx/error.log

ADD files /

EXPOSE 80

CMD ["bash", "/start.sh"]
