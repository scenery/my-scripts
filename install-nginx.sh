#!/bin/bash
# Written by ATP for personal use
# Website: https://atpx.com
# Github: https://github.com/scenery/my-scripts

BUILD_DIR=/tmp/nginx_build_atpx
NGX_PATH=/etc/nginx
CPU_COUNT=$(nproc)

green(){
    echo -e "\033[32m\033[01m$1\033[0m"
}
red(){
    echo -e "\033[31m\033[01m$1\033[0m"
}
yellow(){
    echo -e "\033[33m\033[01m$1\033[0m"
}

ngx_stable() {
    NGX_VER="nginx-${ngx_latest_stable}"
    wget https://nginx.org/download/${NGX_VER}.tar.gz -O "${BUILD_DIR}/${NGX_VER}.tar.gz"
    mkdir -p "${BUILD_DIR}/${NGX_VER}"
    tar -xzvf "${BUILD_DIR}/${NGX_VER}.tar.gz" --directory="${BUILD_DIR}/${NGX_VER}" --strip-components 1
    SSL_VER=`curl -s https://api.github.com/repos/openssl/openssl/releases/latest | grep tag_name | cut -f4 -d "\""`
    SSL_NAME="openssl-${SSL_VER}"
    wget "https://github.com/openssl/openssl/releases/download/${SSL_VER}/${SSL_VER}.tar.gz" -O "${BUILD_DIR}/${SSL_NAME}.tar.gz"
    mkdir -p "${BUILD_DIR}/${SSL_NAME}"
    tar -xzvf "${BUILD_DIR}/${SSL_NAME}.tar.gz" --directory="${BUILD_DIR}/${SSL_NAME}" --strip-components 1
    # Download bortli & webdav ext
    git clone --recursive https://github.com/google/ngx_brotli.git ${BUILD_DIR}/ngx_brotli
    git clone https://github.com/mid1221213/nginx-dav-ext-module.git  ${BUILD_DIR}/ngx_dav_ext
    cd ${BUILD_DIR}/${NGX_VER}
    ./configure $NGX_CONFIGURE \
        --with-openssl=${BUILD_DIR}/${SSL_NAME} \
        || { red "Error: Configuration Nginx failed."; exit 1; }
}

ngx_mainline() {
    NGX_VER="nginx-${ngx_latest_mainline}"
    wget https://nginx.org/download/${NGX_VER}.tar.gz -O "${BUILD_DIR}/${NGX_VER}.tar.gz"
    mkdir -p "${BUILD_DIR}/${NGX_VER}"
    tar -xzvf "${BUILD_DIR}/${NGX_VER}.tar.gz" --directory="${BUILD_DIR}/${NGX_VER}" --strip-components 1
    # Download bortli & webdav ext
    git clone --recursive https://github.com/google/ngx_brotli.git ${BUILD_DIR}/ngx_brotli
    git clone https://github.com/mid1221213/nginx-dav-ext-module.git  ${BUILD_DIR}/ngx_dav_ext
}

ngx_mainline_os() {
    ngx_mainline
    SSL_NAME="openssl"
    SSL_VER=`curl -s https://api.github.com/repos/openssl/openssl/releases/latest | grep tag_name | cut -f4 -d "\""`
    wget "https://github.com/openssl/openssl/releases/download/${SSL_VER}/${SSL_VER}.tar.gz" -O "${BUILD_DIR}/${SSL_NAME}.tar.gz"
    mkdir -p "${BUILD_DIR}/${SSL_NAME}"
    tar -xzvf "${BUILD_DIR}/${SSL_NAME}.tar.gz" --directory="${BUILD_DIR}/${SSL_NAME}" --strip-components 1
    cd ${BUILD_DIR}/${NGX_VER}
    ./configure $NGX_CONFIGURE \
        --with-http_v3_module \
        --with-openssl=${BUILD_DIR}/${SSL_NAME} \
        || { red "Error: Configuration Nginx failed."; exit 1; }
}

ngx_mainline_bs() {
    ngx_mainline
    SSL_NAME="boringssl"
    # Check dependencies
    local DEPENDENCIES="libssl-dev golang"
    for dep in ${DEPENDENCIES}; do
        if ! dpkg -s $dep >/dev/null 2>&1; then
            echo "Installing $dep..."
            apt install -y $dep
        fi
    done
    # Build BoringSSL
    git clone --depth=1 https://github.com/google/boringssl.git ${BUILD_DIR}/${SSL_NAME}
    mkdir -p ${BUILD_DIR}/${SSL_NAME}/build && cd ${BUILD_DIR}/${SSL_NAME}/build
    cmake ..
    make -j$CPU_COUNT || { red "Error: Compilation ${SSL_NAME} failed."; exit 1; }
    cd ${BUILD_DIR}/${NGX_VER}
    ./configure $NGX_CONFIGURE \
        --with-http_v3_module \
        --with-cc-opt="-I${BUILD_DIR}/${SSL_NAME}/include" \
        --with-ld-opt="-L${BUILD_DIR}/${SSL_NAME}/build/ssl -L${BUILD_DIR}/${SSL_NAME}/build/crypto" \
        || { red "Error: Configuration Nginx failed."; exit 1; }
}

ngx_mainline_ls() {
    ngx_mainline
    SSL_NAME="libressl"
    # Check dependencies
    local DEPENDENCIES="autoconf libtool perl"
    for dep in ${DEPENDENCIES}; do
        if ! dpkg -s $dep >/dev/null 2>&1; then
            echo "Installing $dep..."
            apt install -y $dep
        fi
    done
    # Build LibreSSL
    git clone --depth=1 https://github.com/libressl/portable.git ${BUILD_DIR}/${SSL_NAME}
    mkdir -p ${BUILD_DIR}/${SSL_NAME}/build
    cd ${BUILD_DIR}/${SSL_NAME} && ./autogen.sh
    ./configure || { red "Error: Configuration ${SSL_NAME} failed."; exit 1; }
    make -j$CPU_COUNT || { red "Error: Compilation ${SSL_NAME} failed."; exit 1; }
    make install DESTDIR=${BUILD_DIR}/${SSL_NAME}/build || { red "Error: Installation ${SSL_NAME} failed."; exit 1; }
    cd ${BUILD_DIR}/${NGX_VER}
    ./configure $NGX_CONFIGURE \
        --with-http_v3_module \
        --with-cc-opt="-I${BUILD_DIR}/${SSL_NAME}/build/include" \
        --with-ld-opt="-L${BUILD_DIR}/${SSL_NAME}/build/lib" \
        --with-ld-opt="-static" \
        || { red "Error: Configuration Nginx failed."; exit 1; }
}

install_nginx() {
    clean_temp
    SECONDS=0
    # Check dependencies
    local DEPENDENCIES="build-essential libpcre3 libpcre3-dev libxslt1-dev libbrotli-dev zlib1g zlib1g-dev cmake curl git wget"
    for dep in ${DEPENDENCIES}; do
        if ! dpkg -s $dep >/dev/null 2>&1; then
            echo "Installing $dep..."
            apt install -y $dep
        fi
    done
    # Create dir
    mkdir -p ${NGX_PATH}
    mkdir -p ${NGX_PATH}/conf.d
    mkdir -p ${BUILD_DIR}
    # Nginx version
    ngx_latest_stable=$(curl -s https://nginx.org/packages/debian/pool/nginx/n/nginx/ | grep '"nginx_' | sed -n "s/^.*\">nginx_\(.*\)\~.*$/\1/p" | sort -Vr | head -1 | cut -d'-' -f1)
    ngx_latest_mainline=$(curl -s https://nginx.org/packages/mainline/debian/pool/nginx/n/nginx/ | grep '"nginx_' | sed -n "s/^.*\">nginx_\(.*\)\~.*$/\1/p" | sort -Vr | head -1 | cut -d'-' -f1)
    # Nginx configure
    NGX_CONFIGURE="--prefix=${NGX_PATH} \
        --add-module=${BUILD_DIR}/ngx_brotli \
        --add-module=${BUILD_DIR}/ngx_dav_ext \
        --with-http_dav_module \
        --with-http_dav_module \
        --with-http_v2_module \
        --with-http_ssl_module \
        --with-http_gzip_static_module \
        --with-http_stub_status_module \
        --with-http_sub_module \
        --with-http_realip_module \
        --with-stream \
        --with-stream_ssl_module \
        --with-stream_ssl_preread_module"
    echo
    green "Please choose the Nginx version you would like to install: "
    # Choose version
    while :
    do
        echo
        green "  1. Stable (${ngx_latest_stable} with OpenSSL)"
        green "  2. Mainline (${ngx_latest_mainline} with OpenSSL)"
        green "  3. Mainline (${ngx_latest_mainline} with BoringSSL)"
        green "  4. Mainline (${ngx_latest_mainline} with LibreSSL)"
        yellow "  0. Exit"
        echo
        read -p "Enter your menu choice [0-4]: " num
        case "${num}" in
            1)  ngx_stable 
                break ;;
            2)  ngx_mainline_os
                break ;;
            3)  ngx_mainline_bs
                break ;;
            4)  ngx_mainline_ls
                break ;;
            0)  exit 0 ;;
            *)  red "Error: Invalid number." ;;
        esac
    done
    # Build nginx
    cd ${BUILD_DIR}/${NGX_VER}
    make -j$CPU_COUNT || { red "Error: Compilation Nginx failed."; exit 1; }
    make install || { red "Error: Installation Nginx failed."; exit 1; }
    green "Nginx successfully installed."
    green "Installing Nginx systemd service now..."
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
    echo
    echo "----------"
    echo
    nginx -V
    echo
    green "Done!"
    green "Version: ${NGX_VER} with ${SSL_NAME}"
    green "Nginx Path: ${NGX_PATH}"
    green "Temp files: ${BUILD_DIR}"
    green "Status: service nginx status"
    yellow "Total: ${SECONDS} seconds"
}

clean_temp() {
    if [ -d "${BUILD_DIR}" ]; then
        rm -rf ${BUILD_DIR}
    fi
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
    green "+------------------------------------------------------------+"
    green "| A tool for auto-compiling and installing the latest Nginx  |"
    green "| Author : ATP <https://atpx.com>                            |"
    green "| Github : https://github.com/scenery/my-scripts             |"
    green "+------------------------------------------------------------+"
    while :
    do
        echo
        green "  1. Install Nginx"
        red "  2. Delete temp files"
        yellow "  0. Exit"
        echo
        read -p "Enter your menu choice [0-2]: " num
        case "${num}" in
        1)  install_nginx ;;
        2)  clean_temp 
            green "Temp file cleanup completed." ;;
        0)  exit 0 ;;
        *)  red "Error: Invalid number." ;;
        esac
    done
}

main
