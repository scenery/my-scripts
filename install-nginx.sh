#!/bin/bash
# Written by ATP for personal use
# Website: https://atpx.com
# Github: https://github.com/scenery/my-scripts

NGXSTABLE=$(curl -s https://nginx.org/packages/debian/pool/nginx/n/nginx/ | grep '"nginx_' | sed -n "s/^.*\">nginx_\(.*\)\~.*$/\1/p" |sort -Vr |head -1| cut -d'-' -f1)
NGXVER="nginx-"$NGXSTABLE
NGXBUILD=/home/nginx-build-temp

green(){
    echo -e "\033[32m\033[01m$1\033[0m"
}
red(){
    echo -e "\033[31m\033[01m$1\033[0m"
}
yellow(){
    echo -e "\033[33m\033[01m$1\033[0m"
}

install_nginx() {
    if [ -d "$NGXBUILD" ]; then
        rm -rf $NGXBUILD
    fi
    SECONDS=0
    green "================Start Installing Nginx==============="
    sleep 1
    NOW=$(date +"%Y-%m-%d")
    apt update
    apt install -y build-essential libpcre3 libpcre3-dev zlib1g zlib1g-dev cmake curl git wget openssl
    mkdir /etc/nginx
    mkdir /etc/nginx/conf.d
    mkdir -p $NGXBUILD && cd $NGXBUILD
    wget https://nginx.org/download/$NGXVER.tar.gz
    tar -xzvf $NGXVER.tar.gz && rm $NGXVER.tar.gz
    git clone https://github.com/arut/nginx-dav-ext-module
    git clone --recurse-submodules -j8 https://github.com/google/ngx_brotli
    cd ngx_brotli/deps/brotli
    mkdir out && cd out
    cmake -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=OFF -DCMAKE_C_FLAGS="-Ofast -m64 -march=native -mtune=native -flto -funroll-loops -ffunction-sections -fdata-sections -Wl,--gc-sections" -DCMAKE_CXX_FLAGS="-Ofast -m64 -march=native -mtune=native -flto -funroll-loops -ffunction-sections -fdata-sections -Wl,--gc-sections" -DCMAKE_INSTALL_PREFIX=./installed ..
    cmake --build . --config Release --target brotlienc
    cd $NGXBUILD/$NGXVER
    export CFLAGS="-m64 -march=native -mtune=native -Ofast -flto -funroll-loops -ffunction-sections -fdata-sections -Wl,--gc-sections"
    export LDFLAGS="-m64 -Wl,-s -Wl,-Bsymbolic -Wl,--gc-sections"
    ./configure \
        --prefix=/etc/nginx \
        --with-http_v2_module \
        --with-http_ssl_module \
        --with-http_gzip_static_module \
        --with-http_stub_status_module \
        --with-http_sub_module \
        --with-http_realip_module \
        --with-http_dav_module \
        --with-stream \
        --with-stream_ssl_module \
        --with-stream_ssl_preread_module \
        --add-module=../ngx_brotli \
        --add-module=../nginx-dav-ext-module
    make && make install
    
cat > /lib/systemd/system/nginx.service <<-EOF
[Unit]
Description=Nginx - High Performance Web Server
Documentation=http://nginx.org/en/docs/
After=network.target remote-fs.target nss-lookup.target
Wants=network-online.target
 
[Service]
Type=forking
ExecStartPre=/etc/nginx/sbin/nginx -t -c /etc/nginx/conf/nginx.conf
ExecStart=/etc/nginx/sbin/nginx -c /etc/nginx/conf/nginx.conf
ExecReload=/bin/kill -s HUP $MAINPID
ExecStop=/bin/kill -s TERM $MAINPID
ExecStopPost=/bin/rm -f /run/nginx.pid
PrivateTmp=true
 
[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable nginx.service
    systemctl start nginx.service
    ln -s /etc/nginx/sbin/nginx /usr/local/bin
    /etc/nginx/sbin/nginx -V
    green "================Nginx Install Success================"
    green "Program Path: /etc/nginx/"
    green "Temp files: $NGXBUILD"
    green "Status: service nginx status"
    yellow "Total: $SECONDS seconds"
    green "====================================================="
}

clean_temp() {
    echo
    if [ -d "$NGXBUILD" ]; then
        rm -rf $NGXBUILD
    fi
    green "Cleanup done!"
    echo
}

main() {
    if [ $(id -u) != "0" ]; then
        red "Error: This script must be run as root."
        exit 1
    fi   
    if [ ! -f /etc/debian_version ]; then
        red "Error: This script only supports Debian GNU/Linux Operating System."
        exit 1
    fi
    # clear
    green "+---------------------------------------------------+"
    green "| A tool to auto-compile & install $NGXVER     |"
    green "| Author : ATP <https://atpx.com>                   |"
    green "| Github : https://github.com/scenery/my-scripts    |"
    green "+---------------------------------------------------+"
    echo
    while :
    do
        echo
        green " 1. Install Nginx"
        red " 2. Delete temp files"
        yellow " 0. Exit"
        echo
        read -p "Enter your menu choice [0-2]: " num
        case "$num" in
        1)  install_nginx ;;
        2)  clean_temp ;;
        0)  exit 0 ;;
        *)  red "Error: Invalid number." ;;
        esac
    done
}

main
