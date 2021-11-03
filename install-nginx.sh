#!/bin/bash
# Written on 2021-09-19 by ATP for personal test
# Website: https://www.zatp.com
# Github: https://github.com/scenery/my-scripts

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
    SECONDS=0
    green "================Start Installing Nginx==============="
    sleep 1
    apt install build-essential libpcre3 libpcre3-dev zlib1g-dev gcc make curl ca-certificates git wget -y
    mkdir /root/nginx-temp && cd /root/nginx-temp
    # nginx-cache-purge
    # wget https://github.com/FRiCKLE/ngx_cache_purge/archive/2.3.tar.gz
    # tar -zxvf 2.3.tar.gz
    wget https://www.openssl.org/source/openssl-1.1.1l.tar.gz
    tar -xzvf openssl-1.1.1l.tar.gz && rm openssl-1.1.1l.tar.gz
    mkdir /etc/nginx
    mkdir /etc/nginx/conf.d
    git clone https://github.com/google/ngx_brotli
    cd ngx_brotli && git submodule update --init
    cd /root/nginx-temp
    wget https://nginx.org/download/nginx-1.20.1.tar.gz
    tar xf nginx-1.20.1.tar.gz && rm nginx-1.20.1.tar.gz
    cd nginx-1.20.1
    ./configure \
        --prefix=/etc/nginx \
        --with-openssl=../openssl-1.1.1l \
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
    #    --add-module=../ngx_cache_purge-2.3
    make && make install
    
cat > /lib/systemd/system/nginx.service <<-EOF
[Unit]
Description=Nginx - High Performance Web Server
Documentation=http://nginx.org/en/docs/
After=network.target remote-fs.target nss-lookup.target
Wants=network-online.target
 
[Service]
Type=forking
PIDFile=/etc/nginx/logs/nginx.pid
ExecStartPre=/etc/nginx/sbin/nginx -t -c /etc/nginx/conf/nginx.conf
ExecStart=/etc/nginx/sbin/nginx -c /etc/nginx/conf/nginx.conf
ExecReload=/bin/kill -s HUP $MAINPID
ExecStop=/bin/kill -s TERM $MAINPID
PrivateTmp=true
 
[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable nginx.service
    systemctl start nginx.service
    green "================Nginx Install Success================"
    green "Nginx Version: 1.20.1"
    green "Openssl Version: 1.1.1l"
    green "Program Path: /etc/nginx/"
    green "Status: service nginx status"
    yellow "Total: $SECONDS seconds"
    green "====================================================="
}

clean_temp() {
    rm -rf /root/nginx-temp
    green "Clean up success!"
}

main() {
    clear
    green "+---------------------------------------------------+"
    green "| Auto Compiling and Installing Nginx-1.20.1        |"
    green "| Author : Atp <hello@zatp.com>                     |"
    green "| Github : https://github.com/scenery/my-scripts    |"
    green "| **This script only supports Debian GNU/Linux**    |"
    green "+---------------------------------------------------+"
    echo
    green " 1. Install Nginx"
    green " 2. Delete temp installation files"
    yellow " 0. Exit"
    echo
    read -p "Enter a number: " num
    case "$num" in
    1)
        install_nginx
        ;;
    2)
        clean_temp
        ;;
    0)
        exit 1
        ;;
    *)
        clear
        red "Invalid number!"
        sleep 2s
        main
        ;;
    esac
}

# Run
main
