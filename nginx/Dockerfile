FROM        util AS nginx

# HTTP
EXPOSE      80/tcp
# HTTPS
EXPOSE      443/tcp
# RTMP
EXPOSE      1935/tcp

ARG         URL_NGINX_TARBALL=https://nginx.org/download/nginx-1.16.0.tar.gz
ARG         GIT_NGINX_RTMP_MODULE=https://github.com/arut/nginx-rtmp-module
ARG         VERSION_NGINX_RTMP_MODULE=v1.2.1

# nginx
WORKDIR     $PATH_APP
RUN         curl -sL --retry 5 --retry-delay 60 $URL_NGINX_TARBALL -o nginx.tar.gz && \
            tar -xf nginx.tar.gz --one-top-level=nginx --strip-components 1
WORKDIR     $PATH_APP/nginx

# nginx modules
RUN         git clone --verbose \
                --depth 1 \
                --single-branch \
                --branch $VERSION_NGINX_RTMP_MODULE \
                -- $GIT_NGINX_RTMP_MODULE nginx-rtmp-module

# @see: http://nginx.org/en/docs/configure.html
# compile --without-http_gzip_module, thus need not --with-zlib,
# because `gzip on` is not secure when using with `ssl`
RUN         ./configure --user=www-data --group=www-data \
                --prefix=/usr/share/nginx \
                --sbin-path=/usr/sbin \
                --conf-path=/etc/nginx/nginx.conf \
                --http-log-path=/var/log/nginx/access.log \
                --error-log-path=/var/log/nginx/error.log \
                --lock-path=/var/lock/nginx.lock \
                --pid-path=/run/nginx.pid \
                --modules-path=/usr/lib/nginx/modules \
                --http-client-body-temp-path=/var/lib/nginx/body \
                --http-fastcgi-temp-path=/var/lib/nginx/fastcgi \
                --http-proxy-temp-path=/var/lib/nginx/proxy \
                --http-scgi-temp-path=/var/lib/nginx/scgi \
                --http-uwsgi-temp-path=/var/lib/nginx/uwsgi \
                --with-threads \
                --with-file-aio \
                --with-ipv6 \
                --with-http_ssl_module \
                --with-http_v2_module \
                --with-http_realip_module \
                --with-http_stub_status_module \
                --with-openssl="$PATH_APP/openssl" \
                --with-pcre="$PATH_APP/pcre" \
                --without-http_gzip_module \
                --add-module="$PATH_APP/nginx/nginx-rtmp-module"
RUN         make
RUN         make install

WORKDIR     /tmp/self/nginx
# @see: [Difference between “chmod 775” and “chmod 2755”](https://unix.stackexchange.com/questions/52707/difference-between-chmod-775-and-chmod-2755)
RUN         mkdir -p /etc/nginx && \
            chmod 2755 /etc/nginx && \
            chown root:root /etc/nginx
ADD         .config /tmp/nginx/config
RUN         cp -r /tmp/nginx/config/* /

# nginx test
RUN         nginx -V || echo "Fail to compile Nginx!"
RUN         nginx -T || echo "Invalid Nginx configuration file!"
