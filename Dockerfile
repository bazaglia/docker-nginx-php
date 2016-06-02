FROM alpine:latest
MAINTAINER Andre Bazaglia <andre@bazaglia.com>

ENV TIMEZONE=America/Sao_Paulo \
    PHP_MEMORY_LIMIT=128M MAX_UPLOAD=8M PHP_MAX_FILE_UPLOAD=8M PHP_MAX_POST=8M \
    NGINX_VERSION=1.10.1 \
    PAGESPEED_VERSION=1.11.33.2 \
    SOURCE_DIR=/tmp/src \
    LIBPNG_LIB=libpng12 \
    LIBPNG_VERSION=1.2.56

# Upgrade to v3.4 & enable testing repo
RUN sed -i 's/v3.3/v3.4/' /etc/apk/repositories && \
    echo "http://dl-cdn.alpinelinux.org/alpine/edge/testing" >> /etc/apk/repositories

# Let's roll
RUN	apk update && \
	apk upgrade && \
	apk add --update tzdata && \
	ln -snf /usr/share/zoneinfo/${TIMEZONE} /etc/localtime && echo ${TIMEZONE} > /etc/timezone && \
	apk add --update \
	bash curl git ca-certificates nodejs \
	php7-fpm php7-json php7-zlib php7-xml php7-pdo php7-phar php7-curl php7-openssl php7-dom php7-intl php7-ctype \
        php7-pdo_mysql php7-mysqli php7-opcache \
        php7-gd php7-iconv php7-mcrypt php7-mbstring && \
	sed -i "s|;*daemonize\s*=\s*yes|daemonize = no|g" /etc/php7/php-fpm.conf && \
        sed -i "s|;*listen\s*=\s*127.0.0.1:9000|listen = 9000|g" /etc/php7/php-fpm.conf && \
        sed -i "s|;*listen\s*=\s*/||g" /etc/php7/php-fpm.conf && \
        sed -i "s|;*date.timezone =.*|date.timezone = ${TIMEZONE}|i" /etc/php7/php.ini && \
        sed -i "s|;*memory_limit =.*|memory_limit = ${PHP_MEMORY_LIMIT}|i" /etc/php7/php.ini && \
        sed -i "s|;*upload_max_filesize =.*|upload_max_filesize = ${MAX_UPLOAD}|i" /etc/php7/php.ini && \
        sed -i "s|;*max_file_uploads =.*|max_file_uploads = ${PHP_MAX_FILE_UPLOAD}|i" /etc/php7/php.ini && \
        sed -i "s|;*post_max_size =.*|post_max_size = ${PHP_MAX_POST}|i" /etc/php7/php.ini && \
        sed -i "s|;*cgi.fix_pathinfo=.*|cgi.fix_pathinfo= 0|i" /etc/php7/php.ini && \
        ln -s /usr/bin/php7 /usr/bin/php && \
        apk del tzdata && \
	rm -rf /var/cache/apk/*

# nginx
ADD src /tmp/src

RUN \
    apk --update add \
        ca-certificates \
        libuuid \
        apr \
        apr-util \
        libjpeg-turbo \
        icu \
        icu-libs \
        openssl \
        pcre \
        zlib && \
    apk --update add -t .build-deps \
        apache2-dev \
        apr-dev \
        apr-util-dev \
        build-base \
        icu-dev \
        libjpeg-turbo-dev \
        linux-headers \
        gperf \
        openssl-dev \
        pcre-dev \
        python \
        wget \
        zlib-dev && \
    cd ${SOURCE_DIR} && \
    wget -O- https://dl.google.com/dl/linux/mod-pagespeed/tar/beta/mod-pagespeed-beta-${PAGESPEED_VERSION}-r0.tar.bz2 --no-check-certificate | tar -jxv && \
    wget -O- http://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz | tar -zxv && \
    wget -O- ftp://ftp.simplesystems.org/pub/libpng/png/src/${LIBPNG_LIB}/libpng-${LIBPNG_VERSION}.tar.gz | tar -zxv && \
    wget -O- https://github.com/pagespeed/ngx_pagespeed/archive/v${PAGESPEED_VERSION}-beta.tar.gz --no-check-certificate | tar -zxv && \
    cd ${SOURCE_DIR}/libpng-${LIBPNG_VERSION} && \
    ./configure --build=$CBUILD --host=$CHOST --prefix=/usr --enable-shared --with-libpng-compat && \
    make && \
    make install && \
    cd ${SOURCE_DIR}/modpagespeed-${PAGESPEED_VERSION} && \
    patch -p1 -i ${SOURCE_DIR}/patches/automatic_makefile.patch && \
    patch -p1 -i ${SOURCE_DIR}/patches/libpng_cflags.patch && \
    patch -p1 -i ${SOURCE_DIR}/patches/pthread_nonrecursive_np.patch && \
    patch -p1 -i ${SOURCE_DIR}/patches/rename_c_symbols.patch && \
    patch -p1 -i ${SOURCE_DIR}/patches/stack_trace_posix.patch && \
    ./generate.sh -D use_system_libs=1 -D _GLIBCXX_USE_CXX11_ABI=0 -D use_system_icu=1 && \
    cd ${SOURCE_DIR}/modpagespeed-${PAGESPEED_VERSION}/src && \
    make BUILDTYPE=Release CXXFLAGS=" -I/usr/include/apr-1 -I${SOURCE_DIR}/libpng-${LIBPNG_VERSION} -fPIC -D_GLIBCXX_USE_CXX11_ABI=0" CFLAGS=" -I/usr/include/apr-1 -I${SOURCE_DIR}/libpng-${LIBPNG_VERSION} -fPIC -D_GLIBCXX_USE_CXX11_ABI=0" && \
    cd ${SOURCE_DIR}/modpagespeed-${PAGESPEED_VERSION}/src/pagespeed/automatic/ && \
    make psol BUILDTYPE=Release CXXFLAGS=" -I/usr/include/apr-1 -I${SOURCE_DIR}/libpng-${LIBPNG_VERSION} -fPIC -D_GLIBCXX_USE_CXX11_ABI=0" CFLAGS=" -I/usr/include/apr-1 -I${SOURCE_DIR}/libpng-${LIBPNG_VERSION} -fPIC -D_GLIBCXX_USE_CXX11_ABI=0" && \
    mkdir -p ${SOURCE_DIR}/ngx_pagespeed-${PAGESPEED_VERSION}-beta/psol && \
    mkdir -p ${SOURCE_DIR}/ngx_pagespeed-${PAGESPEED_VERSION}-beta/psol/lib/Release/linux/x64 && \
    mkdir -p ${SOURCE_DIR}/ngx_pagespeed-${PAGESPEED_VERSION}-beta/psol/include/out/Release && \
    cp -r ${SOURCE_DIR}/modpagespeed-${PAGESPEED_VERSION}/src/out/Release/obj ${SOURCE_DIR}/ngx_pagespeed-${PAGESPEED_VERSION}-beta/psol/include/out/Release/ && \
    cp -r ${SOURCE_DIR}/modpagespeed-${PAGESPEED_VERSION}/src/net ${SOURCE_DIR}/ngx_pagespeed-${PAGESPEED_VERSION}-beta/psol/include/ && \
    cp -r ${SOURCE_DIR}/modpagespeed-${PAGESPEED_VERSION}/src/testing ${SOURCE_DIR}/ngx_pagespeed-${PAGESPEED_VERSION}-beta/psol/include/ && \
    cp -r ${SOURCE_DIR}/modpagespeed-${PAGESPEED_VERSION}/src/pagespeed ${SOURCE_DIR}/ngx_pagespeed-${PAGESPEED_VERSION}-beta/psol/include/ && \
    cp -r ${SOURCE_DIR}/modpagespeed-${PAGESPEED_VERSION}/src/third_party ${SOURCE_DIR}/ngx_pagespeed-${PAGESPEED_VERSION}-beta/psol/include/ && \
    cp -r ${SOURCE_DIR}/modpagespeed-${PAGESPEED_VERSION}/src/tools ${SOURCE_DIR}/ngx_pagespeed-${PAGESPEED_VERSION}-beta/psol/include/ && \
    cp -r ${SOURCE_DIR}/modpagespeed-${PAGESPEED_VERSION}/src/pagespeed/automatic/pagespeed_automatic.a ${SOURCE_DIR}/ngx_pagespeed-${PAGESPEED_VERSION}-beta/psol/lib/Release/linux/x64 && \
    cd ${SOURCE_DIR}/nginx-${NGINX_VERSION} && \
    LD_LIBRARY_PATH=${SOURCE_DIR}/modpagespeed-${PAGESPEED_VERSION}/usr/lib ./configure --with-ipv6 \
        --prefix=/etc/nginx \
        --sbin-path=/usr/sbin/nginx \
        --conf-path=/etc/nginx/nginx.conf \
        --error-log-path=/var/log/nginx/error.log \
        --http-log-path=/var/log/nginx/access.log \
        --pid-path=/var/run/nginx.pid \
        --lock-path=/var/run/nginx.lock \
        --http-client-body-temp-path=/var/cache/nginx/client_temp \
        --http-proxy-temp-path=/var/cache/nginx/proxy_temp \
        --http-fastcgi-temp-path=/var/cache/nginx/fastcgi_temp \
        --http-uwsgi-temp-path=/var/cache/nginx/uwsgi_temp \
        --http-scgi-temp-path=/var/cache/nginx/scgi_temp \
        --user=nginx \
        --group=nginx \
        --modules-path=/usr/lib/nginx \
        --with-http_ssl_module \
        --with-http_realip_module \
        --with-http_gzip_static_module \
        --with-file-aio \
        --with-http_v2_module \
        --without-http_autoindex_module \
        --without-http_browser_module \
        --without-http_geo_module \
        --without-http_map_module \
        --without-http_memcached_module \
        --without-http_userid_module \
        --without-mail_pop3_module \
        --without-mail_imap_module \
        --without-mail_smtp_module \
        --without-http_split_clients_module \
        --without-http_uwsgi_module \
        --without-http_scgi_module \
        --without-http_referer_module \
        --without-http_upstream_ip_hash_module \
        --add-module=${SOURCE_DIR}/ngx_pagespeed-${PAGESPEED_VERSION}-beta \
        --with-cc-opt="-fPIC -I /usr/include/apr-1" \
        --with-ld-opt="-luuid -lapr-1 -laprutil-1 -licudata -licuuc -L${SOURCE_DIR}/modpagespeed-${PAGESPEED_VERSION}/usr/lib -lpng12 -lturbojpeg -ljpeg" && \
    make && \
    make install && \
    ln -sf /dev/stdout /var/log/nginx/access.log && \
    ln -sf /dev/stderr /var/log/nginx/error.log && \
    adduser -D nginx && \
    mkdir /var/cache/nginx && \
    mkdir /var/cache/ngx_pagespeed_cache && \
    apk del .build-deps && \
    rm -rf /tmp/* && \
    rm -rf /var/cache/apk/*

#composer & bower
RUN curl -sS https://getcomposer.org/installer --insecure | php && \
    mv composer.phar /usr/bin/composer && \
    composer global require "fxp/composer-asset-plugin:~1.1"
ENV PATH /root/.composer/vendor/bin:$PATH
RUN npm install -g bower

EXPOSE 80
