#!/bin/bash
# Written by ATP for personal use
# Website: https://atpx.com
# Github: https://github.com/scenery/my-scripts

NGX_STABLE=$(curl -s https://nginx.org/packages/debian/pool/nginx/n/nginx/ | grep '"nginx_' | sed -n "s/^.*\">nginx_\(.*\)\~.*$/\1/p" |sort -Vr |head -1| cut -d'-' -f1)
NGX_VER="nginx-"$NGX_STABLE
NGX_BUILD_PATH=/home/nginx-build-temp
NGX_PATH=/etc/nginx
OPENSSL_VER=`curl -s https://api.github.com/repos/openssl/openssl/releases/latest | grep tag_name | cut -f4 -d "\""`

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
    if [ -d "${NGX_BUILD_PATH}" ]; then
        rm -rf ${NGX_BUILD_PATH}
    fi
    SECONDS=0
    green "================Start Installing Nginx==============="
    apt update
    apt install -y build-essential libpcre3 libpcre3-dev libxslt1-dev libbrotli-dev zlib1g zlib1g-dev cmake curl git wget
    mkdir ${NGX_PATH}
    mkdir ${NGX_PATH}/conf.d
    mkdir -p ${NGX_BUILD_PATH} && cd ${NGX_BUILD_PATH}
    wget https://nginx.org/download/${NGX_VER}.tar.gz
    tar -xzvf ${NGX_VER}.tar.gz && rm ${NGX_VER}.tar.gz
    wget https://github.com/openssl/openssl/releases/download/${OPENSSL_VER}/${OPENSSL_VER}.tar.gz
    tar -xzvf ${OPENSSL_VER}.tar.gz && rm ${OPENSSL_VER}.tar.gz
    git clone --recursive https://github.com/google/ngx_brotli.git
    git clone https://github.com/arut/nginx-dav-ext-module.git
    cd ${NGX_BUILD_PATH}/${NGX_VER}
    ./configure \
        --prefix=${NGX_PATH} \
        --with-openssl=../${OPENSSL_VER} \
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
    echo "Installing Nginx systemd service..."
    cat > /etc/systemd/system/nginx.service << EOF
[Unit]
Description=Nginx - High Performance Web Server
Documentation=http://nginx.org/en/docs/
After=network.target remote-fs.target nss-lookup.target
Wants=network-online.target
 
[Service]
Type=forking
ExecStartPre=${NGX_PATH}/sbin/nginx -t -c ${NGX_PATH}/conf/nginx.conf
ExecStart=${NGX_PATH}/sbin/nginx -c ${NGX_PATH}/conf/nginx.conf
ExecReload=${NGX_PATH}/sbin/nginx -s reload
ExecStop=${NGX_PATH}/sbin/nginx -s stop
PrivateTmp=true
 
[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable nginx.service
    systemctl start nginx.service
    if [ -L "/usr/local/bin/nginx" ]; then
        yellow "Old Nginx symbolic link exists. Cancell the link"
        rm /usr/local/bin/nginx
    fi
    yellow "Set up Nginx symbolic link"
    ln -s /etc/nginx/sbin/nginx /usr/local/bin/nginx
    chmod +x /usr/local/bin/nginx
    nginx -V
    green "Done!"
    green "Version: ${NGX_VER} with ${OPENSSL_VER}"
    green "Program Path: /etc/nginx/"
    green "Temp files: ${NGX_BUILD_PATH}"
    green "Status: service nginx status"
    yellow "Total: ${SECONDS} seconds"
}

clean_temp() {
    echo
    if [ -d "${NGX_BUILD_PATH}" ]; then
        rm -rf ${NGX_BUILD_PATH}
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
    green "| A tool to auto-compile & install ${NGX_VER}     |"
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
