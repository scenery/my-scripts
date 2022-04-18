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
    NOW=$(date +"%Y-%m-%d")
    apt install build-essential libpcre3 libpcre3-dev zlib1g-dev gcc make curl ca-certificates git wget -y
    mkdir /etc/nginx
    mkdir /etc/nginx/conf.d
    mkdir /root/nginx-temp
    cd /root/nginx-temp
    # nginx-cache-purge
    # wget https://github.com/FRiCKLE/ngx_cache_purge/archive/2.3.tar.gz
    # tar -zxvf 2.3.tar.gz
    wget https://www.openssl.org/source/openssl-1.1.1n.tar.gz
    tar -xzvf openssl-1.1.1n.tar.gz && rm openssl-1.1.1n.tar.gz
    git clone https://github.com/google/ngx_brotli
    cd ngx_brotli && git submodule update --init
    cd /root/nginx-temp
    wget https://nginx.org/download/nginx-1.20.2.tar.gz
    tar xf nginx-1.20.2.tar.gz && rm nginx-1.20.2.tar.gz
    cd nginx-1.20.2
    ./configure \
        --prefix=/etc/nginx \
        --with-openssl=../openssl-1.1.1n \
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
    green "================Nginx Install Success================"
    green "Nginx Version: 1.20.2"
    green "Openssl Version: 1.1.1m"
    green "Program Path: /etc/nginx/"
    green "Temp files: /root/nginx-temp"
    green "Status: service nginx status"
    yellow "Total: $SECONDS seconds"
    green "====================================================="
}

clean_temp() {
    echo
    if [ -d "/root/nginx-temp" ]; then
        rm -rf /root/nginx-temp
    fi
    green "Cleanup done!"
    echo
}


if [ $(id -u) != "0" ]; then
    red "Error: You must be root to run this script."
    exit 1
fi   
if [ ! -f /etc/debian_version ]; then
    red "Error: This script only supports Debian GNU/Linux Operating System."
    exit 1
fi
# clear
green "+---------------------------------------------------+"
green "| A tool to auto-compile & install Nginx-1.20.2     |"
green "| Author : ATP <hi@zatp.com>                        |"
green "| Github : https://github.com/scenery/my-scripts    |"
green "+---------------------------------------------------+"
echo
while getopts ":ic" option; do
    case "${option}" in
    i)  install_nginx ;;
    c)  clean_temp ;;
    \?) echo "Invalid option, you have to use: [-i] or [-c]"
        echo "-i: Install Nginx"
        echo "-c: Delete temp files" ;;
    esac
done
if [ $OPTIND = "1" ]; then
    echo
    green " 1. Install Nginx"
    red " 2. Delete temp files"
    yellow " 0. Exit"
    echo
    echo -n "Enter a number: "
    while :
    do
    read num
    case "$num" in
        1)  install_nginx ;;
        2)  clean_temp ;;
        0)  exit 0 ;;
        *)  red "Invalid option."
            echo -n "Enter a number [0-2]: " ;;
    esac
    done
fi

