#!/bin/bash
WORKSPACE="$(pwd)/.workspace"
SRC="$WORKSPACE/src.nginx"
NGINX_VERSION=1.13.12
NGINX_DL_PATH=http://nginx.org/download/nginx-1.13.12.tar.gz
HM_VERSION=0.33
NPS_VERSION=1.13.35.2

GH_RAW_PATH=https://raw.githubusercontent.com/sayuthisobri/centos-nginx/master

[ ! -d $WORKSPACE ] && mkdir -p $WORKSPACE
pushd $WORKSPACE

yum update -y
yum upgrade -y
yum install -y gcc-c++ pcre-dev pcre-devel perl perl-devel perl-ExtUtils-Embed zlib-devel \
	make wget unzip openssl openssl-devel uuid-devel libuuid-devel gd gd-devel GeoIP GeoIP-devel

[ ! -d $SRC ] && mkdir -p $SRC

pushd $SRC

[ ! -d nginx-$NGINX_VERSION ] && curl -fSL https://nginx.org/download/nginx-$NGINX_VERSION.tar.gz -o nginx.tar.gz \
	&& tar -zxf nginx.tar.gz

[ ! -d headers-more-nginx-module-$HM_VERSION ] \
	&& curl -fSL https://github.com/openresty/headers-more-nginx-module/archive/v$HM_VERSION.tar.gz -o more-module.tar.gz \
	&& tar -zxf more-module.tar.gz

[ ! -d incubator-pagespeed-ngx-${NPS_VERSION}-stable ] && curl -fSL https://github.com/pagespeed/ngx_pagespeed/archive/v${NPS_VERSION}-stable.zip \
	-o ngx_pagespeed.zip \
	&& unzip ngx_pagespeed.zip

pushd incubator-pagespeed-ngx-${NPS_VERSION}-stable
[ ! -d psol ] && curl -fSL https://dl.google.com/dl/page-speed/psol/${NPS_VERSION}-x64.tar.gz -o psol.tar.gz \
	&& tar -xzvf psol.tar.gz
popd

# Extract all src files
# for file in *.tar.gz; do
#     [ -e "$file" ] && tar -zxf $file
# done

pushd nginx-$NGINX_VERSION
./configure --prefix=/etc/nginx \
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
--build=CentOS \
--with-select_module \
--with-poll_module \
--with-threads \
--with-file-aio \
--with-http_ssl_module \
--with-http_v2_module \
--with-http_realip_module \
--with-http_addition_module \
--with-http_image_filter_module=dynamic \
--with-http_geoip_module=dynamic \
--with-http_perl_module=dynamic \
--with-http_sub_module \
--with-http_dav_module \
--with-http_flv_module \
--with-http_mp4_module \
--with-http_gunzip_module \
--with-http_gzip_static_module \
--with-http_auth_request_module \
--with-http_random_index_module \
--with-http_secure_link_module \
--with-http_degradation_module \
--with-http_slice_module \
--with-http_stub_status_module \
--with-mail=dynamic \
--with-mail_ssl_module \
--with-stream=dynamic \
--with-stream_ssl_module \
--with-stream_realip_module \
--with-stream_geoip_module=dynamic \
--with-stream_ssl_preread_module \
--with-compat \
--add-module=$SRC/headers-more-nginx-module-$HM_VERSION \
--add-module=$SRC/incubator-pagespeed-ngx-${NPS_VERSION}-stable

make
sudo make install

mkdir -p /var/cache/nginx /etc/nginx/conf.d /var/www/html
[ `id -u nginx 2>/dev/null || echo -1` -eq -1 ] && useradd --system --home /var/cache/nginx --shell /sbin/nologin --comment "nginx user" --user-group nginx
chown nginx:nginx /var/www/html
cp /etc/nginx/html/* /var/www/html/
rm -rf /etc/nginx/html

# Replace config files
pushd /etc/nginx
curl -fSLO $GH_RAW_PATH/nginx.conf
pushd conf.d
curl -fSLO $GH_RAW_PATH/conf.d/default.conf

# Remove working directory
rm -rf $WORKSPACE

echo "[Unit]
Description=The NGINX HTTP and reverse proxy server
After=syslog.target network.target remote-fs.target nss-lookup.target

[Service]
Type=forking
PIDFile=/run/nginx.pid
ExecStartPre=/usr/sbin/nginx -t
ExecStart=/usr/sbin/nginx
ExecReload=/usr/sbin/nginx -s reload
ExecStop=/bin/kill -s QUIT $MAINPID
PrivateTmp=true

[Install]
WantedBy=multi-user.target" > /lib/systemd/system/nginx.service
