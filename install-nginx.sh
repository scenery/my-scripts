#!/bin/bash
# Written by ATP for personal use
# Website: https://atpx.com
# Github: https://github.com/scenery/my-scripts

BUILD_DIR=/tmp/nginx-build
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
    local ngx_latest=$(curl -s https://nginx.org/packages/debian/pool/nginx/n/nginx/ | grep '"nginx_' | sed -n "s/^.*\">nginx_\(.*\)\~.*$/\1/p" | sort -Vr | head -1 | cut -d'-' -f1)
    NGX_VER="nginx-${ngx_latest}"
    wget https://nginx.org/download/${NGX_VER}.tar.gz -O "${BUILD_DIR}/${NGX_VER}.tar.gz"
    mkdir -p "${BUILD_DIR}/${NGX_VER}"
    tar -xzvf "${BUILD_DIR}/${NGX_VER}.tar.gz" --directory="${BUILD_DIR}/${NGX_VER}" --strip-components 1
    SSL_VER=`curl -s https://api.github.com/repos/openssl/openssl/releases/latest | grep tag_name | cut -f4 -d "\""`
    SSL_NAME="openssl-${SSL_VER}"
    wget "https://github.com/openssl/openssl/releases/download/${SSL_VER}/${SSL_VER}.tar.gz" -O "${BUILD_DIR}/${SSL_NAME}.tar.gz"
    mkdir -p "${BUILD_DIR}/${SSL_NAME}"
    tar -xzvf "${BUILD_DIR}/${SSL_NAME}.tar.gz" --directory="${BUILD_DIR}/${SSL_NAME}" --strip-components 1
    # Download bortli
    git clone --recursive https://github.com/google/ngx_brotli.git ${BUILD_DIR}/ngx_brotli
    cd ${BUILD_DIR}/${NGX_VER}
    ./configure $NGX_CONFIGURE \
        --with-openssl=${BUILD_DIR}/${SSL_NAME} \
        || { red "Error: Configuration Nginx failed."; exit 1; }
}

ngx_mainline() {
    local ngx_latest=$(curl -s https://nginx.org/packages/mainline/debian/pool/nginx/n/nginx/ | grep '"nginx_' | sed -n "s/^.*\">nginx_\(.*\)\~.*$/\1/p" | sort -Vr | head -1 | cut -d'-' -f1)
    NGX_VER="nginx-${ngx_latest}"
    wget https://nginx.org/download/${NGX_VER}.tar.gz -O "${BUILD_DIR}/${NGX_VER}.tar.gz"
    mkdir -p "${BUILD_DIR}/${NGX_VER}"
    tar -xzvf "${BUILD_DIR}/${NGX_VER}.tar.gz" --directory="${BUILD_DIR}/${NGX_VER}" --strip-components 1
    # Download bortli
    git clone --recursive https://github.com/google/ngx_brotli.git ${BUILD_DIR}/ngx_brotli
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
    git clone --depth=1 https://github.com/google/boringssl.git ${BUILD_DIR}/boringssl
    mkdir -p ${BUILD_DIR}/boringssl/build && cd ${BUILD_DIR}/boringssl/build
    cmake ..
    make -j$CPU_COUNT || { red "Error: Compilation BoringSSL failed."; exit 1; }
    cd ${BUILD_DIR}/${NGX_VER}
    ./configure $NGX_CONFIGURE \
        --with-http_v3_module \
        --with-cc-opt="-I${BUILD_DIR}/boringssl/include" \
        --with-ld-opt="-L${BUILD_DIR}/boringssl/build/ssl  -L${BUILD_DIR}/boringssl/build/crypto" \
        || { red "Error: Configuration Nginx failed."; exit 1; }
}

install_libressl() {
    # Check dependencies
    local DEPENDENCIES="autoconf libtool perl"
    for dep in ${DEPENDENCIES}; do
        if ! dpkg -s $dep >/dev/null 2>&1; then
            echo "Installing $dep..."
            apt install -y $dep
        fi
    done
    wget "${SSL_URL}/${SSL_NAME}.tar.gz" -O "${BUILD_DIR}/${SSL_NAME}.tar.gz"
    mkdir -p "${BUILD_DIR}/${SSL_NAME}"
    tar -xzvf "${BUILD_DIR}/${SSL_NAME}.tar.gz" --directory="${BUILD_DIR}/${SSL_NAME}" --strip-components 1
    cd ${BUILD_DIR}/${SSL_NAME} && ./autogen.sh
    ./configure --prefix="${SSL_PATH}" || { red "Error: Configuration LibreSSL failed."; exit 1; }
    make -j$CPU_COUNT || { red "Error: Compilation LibreSSL failed."; exit 1; }
    make install || { red "Error: Installation LibreSSL failed."; exit 1; }
}

ngx_mainline_ls() {
    ngx_mainline
    SSL_URL="https://ftp.openbsd.org/pub/OpenBSD/LibreSSL/"
    SSL_PATH="/usr/local/libressl"
    local pattern="libressl-[0-9]+\.[0-9]+\.[0-9]+\.tar\.gz"
    SSL_NAME=$(curl -s ${SSL_URL} | grep -o -E ${pattern} | sort -V | tail -n 1 | sed 's/\.tar\.gz$//')
    if [ -d "${SSL_PATH}" ]; then
        local installed_version=$("${SSL_PATH}/bin/openssl" version | awk '{print $2}')
        local latest_version=$(echo "${SSL_NAME}" | sed 's/libressl-//')
        echo
        echo "Installed LibreSSL version: ${installed_version}"
        if [ "${installed_version}" != "${latest_version}" ]; then
            while : 
            do
            read -p "A newer version (${latest_version}) is available. Do you want to update LibreSSL? (y/n): " goupdate
            case $goupdate in
                [Yy][Ee][Ss]|[Yy]) 
                    install_libressl
                    break ;;
                [Nn][Oo]|[Nn]) 
                    break ;;
                * ) echo -n "Invalid option. Do you want to update? [y/n]: " ;;
            esac
            done
        else
            green "LibreSSL is already up to date."
        fi
    else
        echo
        yellow "LibreSSL is not installed, installing now..."
        install_libressl
    fi
    cd ${BUILD_DIR}/${NGX_VER}
    ./configure $NGX_CONFIGURE \
        --with-http_v3_module \
        --with-cc-opt="-I${SSL_PATH}/include" \
        --with-ld-opt="-L${SSL_PATH}/lib -static" \
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
    # Nginx configure
    NGX_CONFIGURE="--prefix=${NGX_PATH} \
        --add-module=${BUILD_DIR}/ngx_brotli \
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
        green "  1. Stable (with OpenSSL)"
        green "  2. Mainline (with BoringSSL and HTTP/3 support)"
        green "  3. Mainline (with LibreSSL and HTTP/3 support)"
        yellow "  0. Exit"
        echo
        read -p "Enter your menu choice [0-3]: " num
        case "${num}" in
            1)  ngx_stable 
                break ;;
            2)  ngx_mainline_bs
                break ;;
            3)  ngx_mainline_ls
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
    green "+-------------------------------------------------------------+"
    green "| A tool for auto-compiling and installing the latest Nginx   |"
    green "| Author : ATP <https://atpx.com>                             |"
    green "| Github : https://github.com/scenery/my-scripts              |"
    green "+-------------------------------------------------------------+"
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
