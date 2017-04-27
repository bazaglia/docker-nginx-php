#!/bin/bash

if [ -n "$VIRTUAL_HOST" ]; then
  sed -i "s/localhost/$VIRTUAL_HOST/g" /etc/nginx/conf.d/default.conf
fi

php-fpm7
exec nginx
