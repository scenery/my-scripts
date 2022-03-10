# My Scripts

Some useful scripts written by myself, but I have no idea what they are :-)

_Notice: All scripts are use for personal test in single environment (most of them will only run on Debian GNU/Linux) that means it may not be suitable for all people. You must know what you're doing before run them._

## Table of contents

* [Install Nginx](#install-nginx)
* [Traceroute](#traceroute)
* [Unblock Netflix Check](#check-netflix)

## Usage

### install-nginx

Auto compiling and installing latest [Nginx](https://nginx.org/en/download.html) (Stable version)
```
bash <(curl -Ls git.io/nginx.sh)
# or
bash <(curl -Ls https://raw.githubusercontent.com/scenery/my-scripts/main/install-nginx.sh)
```

```
./configure \
    --prefix=/etc/nginx \
    --with-openssl=../openssl-1.1.1m \
    --with-openssl-opt='enable-tls1_3' \
    --with-http_v2_module \
    --with-http_ssl_module \
    --with-http_gzip_static_module \
    --with-http_stub_status_module \
    --with-http_sub_module \
    --with-http_realip_module \
    --with-stream \
    --with-stream_ssl_module \
    --with-stream_ssl_preread_module \
    --add-module=../ngx_brotli
```

### traceroute

A simple tool to test traceroute from your VPS/Server to Mainland China, powered by Besttrace (ipip.net).
```
bash <(curl -Ls git.io/traceroute.sh)
# or
bash <(curl -Ls https://raw.githubusercontent.com/scenery/my-scripts/main/traceroute.sh)
```

### check-netflix

A easy and fast script to check if your IPv4 and IPv6 address can unblock Netflix streaming.
```
bash <(curl -Ls https://raw.githubusercontent.com/scenery/my-scripts/main/check-netflix.sh)
```

