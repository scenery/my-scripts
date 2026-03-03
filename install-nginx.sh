#!/bin/bash
# Written by ATP
# Website: https://atpx.com
# Github: https://github.com/scenery/my-scripts

NGX_PREFIX="/usr/local/nginx"
NGX_SBIN="/usr/local/sbin/nginx"
NGX_CONF_DIR="/etc/nginx"
NGX_CONF="${NGX_CONF_DIR}/nginx.conf"
NGX_LOG_DIR="/var/log/nginx"
NGX_PID="/run/nginx.pid"
NGX_LOCK="/run/nginx.lock"

DEPENDENCIES=(build-essential libpcre3 libpcre3-dev libxslt1-dev libbrotli-dev zlib1g zlib1g-dev cmake curl git wget)
GIT_BROTLI="https://github.com/google/ngx_brotli.git"
GIT_PURGE="https://github.com/nginx-modules/ngx_cache_purge.git"

CPU_COUNT=$(nproc)
ARCH=$(uname -m)
if [[ "$ARCH" == "x86_64" || "$ARCH" == "aarch64" ]]; then
    OPT_FLAGS="-O3"
else
    OPT_FLAGS="-O2"
fi

export CFLAGS="$OPT_FLAGS \
-fstack-protector-strong \
-fstack-clash-protection \
-Wformat -Werror=format-security \
-D_FORTIFY_SOURCE=3 \
-fPIC"
export LDFLAGS="-Wl,-z,relro -Wl,-z,now -Wl,-Bsymbolic-functions -fPIC"

green(){ echo -e "\033[32m\033[01m$1\033[0m"; }
red(){ echo -e "\033[31m\033[01m$1\033[0m"; }
yellow(){ echo -e "\033[33m\033[01m$1\033[0m"; }

get_safe_build_dir() {
    local target_tmp="/tmp"
    local fallback_tmp="/var/tmp"
    local root_build="/root"
    
    local tmp_avail=$(df -k "$target_tmp" | tail -1 | awk '{print $4}')
    
    if [ "$tmp_avail" -gt 2097152 ]; then
        echo "${target_tmp}/nginx_build_atpx"
    else
        local var_avail=$(df -k "$fallback_tmp" | tail -1 | awk '{print $4}')
        if [ "$var_avail" -gt 2097152 ]; then
            echo "${fallback_tmp}/nginx_build_atpx"
        else
            echo "${root_build}/nginx_build_atpx"
        fi
    fi
}

BUILD_DIR=$(get_safe_build_dir)
yellow "Set build directory: ${BUILD_DIR}"
trap '[[ -d "${BUILD_DIR}" ]] && rm -rf "${BUILD_DIR}"' EXIT

NGX_CONFIGURE="--prefix=${NGX_PREFIX} \
    --sbin-path=${NGX_SBIN} \
    --conf-path=${NGX_CONF} \
    --error-log-path=${NGX_LOG_DIR}/error.log \
    --http-log-path=${NGX_LOG_DIR}/access.log \
    --pid-path=${NGX_PID} \
    --lock-path=${NGX_LOCK} \
    --add-module=${BUILD_DIR}/ngx_brotli \
    --add-module=${BUILD_DIR}/ngx_cache_purge \
    --with-http_ssl_module \
    --with-http_v2_module \
    --with-http_v3_module \
    --with-http_realip_module \
    --with-http_gzip_static_module \
    --with-http_stub_status_module \
    --with-http_sub_module \
    --with-stream \
    --with-stream_ssl_module \
    --with-stream_realip_module \
    --with-stream_ssl_preread_module \
    --with-pcre-jit"

download_source() {
    local version=$1
    echo "Downloading Nginx ${version} and modules..."
    mkdir -p ${BUILD_DIR}
    wget https://nginx.org/download/nginx-${version}.tar.gz -O "${BUILD_DIR}/nginx.tar.gz"
    mkdir -p "${BUILD_DIR}/nginx" && tar -xzvf "${BUILD_DIR}/nginx.tar.gz" -C "${BUILD_DIR}/nginx" --strip-components 1
    
    echo "Cloning modules..."
    git clone --recursive ${GIT_BROTLI} ${BUILD_DIR}/ngx_brotli
    git clone ${GIT_PURGE} ${BUILD_DIR}/ngx_cache_purge

    echo "Downloading latest OpenSSL..."
    local ssl_ver=$(curl -s https://api.github.com/repos/openssl/openssl/releases/latest | grep tag_name | cut -f4 -d "\"")
    wget "https://github.com/openssl/openssl/releases/download/${ssl_ver}/${ssl_ver}.tar.gz" -O "${BUILD_DIR}/openssl.tar.gz"
    mkdir -p "${BUILD_DIR}/openssl" && tar -xzvf "${BUILD_DIR}/openssl.tar.gz" -C "${BUILD_DIR}/openssl" --strip-components 1
}

detect_existing_nginx() {
    local found=0

    if command -v nginx >/dev/null 2>&1; then
        NGINX_PATH=$(command -v nginx)
        found=1
    else
        local paths_to_check=(
            "/usr/local/sbin/nginx"
            "/usr/local/nginx/sbin/nginx"
            "/usr/sbin/nginx"
            "/usr/bin/nginx"
            "/etc/nginx/sbin/nginx"
            "/etc/nginx/bin/nginx"
        )

        for p in "${paths_to_check[@]}"; do
            if [ -x "$p" ]; then
                NGINX_PATH="$p"
                found=1
                break
            fi
        done
    fi

    if [ $found -eq 0 ]; then
        return 1
    fi

    NGINX_VERSION=$($NGINX_PATH -v 2>&1 || true)
    NGINX_CONFIG=$($NGINX_PATH -V 2>&1 || true)
    echo
    yellow "Existing Nginx installation detected."
    echo "  Path    : ${NGINX_PATH}"
    echo "  Version : ${NGINX_VERSION}"

    if dpkg -s nginx >/dev/null 2>&1; then
        echo "  Install : APT package"
    elif echo "$NGINX_CONFIG" | grep -q "/usr/local"; then
        echo "  Install : Source compilation"
    else
        echo "  Install : Unknown / Custom build"
    fi

    echo
    yellow "WARNING:"
    echo "Upgrading will overwrite the existing Nginx installation."
    echo "Configuration files may be replaced if paths overlap."
    return 0
}

setup_logrotate() {
    echo "Checking for logrotate service..."
    if dpkg -s logrotate >/dev/null 2>&1; then
        green "Logrotate detected. Configuring automatic log rotation..."
        cat > /etc/logrotate.d/nginx << EOF
${NGX_LOG_DIR}/*.log {
    daily
    missingok
    rotate 90
    compress
    delaycompress
    notifempty
    create 0640 www-data adm
    sharedscripts
    postrotate
        if [ -f ${NGX_PID} ]; then
            kill -USR1 \$(cat ${NGX_PID})
        fi
    endscript
}
EOF
        green "Logrotate config created: /etc/logrotate.d/nginx (Retention: 90 days)"
    else
        echo
        yellow "------------------------------------------------------------"
        yellow "WARNING: 'logrotate' package is not installed."
        yellow "Your logs in ${NGX_LOG_DIR} will grow indefinitely."
        yellow "SUGGESTION: Run 'apt install logrotate' to enable auto-cleaning."
        yellow "------------------------------------------------------------"
        echo
    fi
}

install_nginx() {
    set -e
    echo "Checking system dependencies..."
    MISSING_PACKAGES=()
    for pkg in "${DEPENDENCIES[@]}"; do
        if ! dpkg -s "$pkg" >/dev/null 2>&1; then
            MISSING_PACKAGES+=("$pkg")
        fi
    done

    if [ ${#MISSING_PACKAGES[@]} -gt 0 ]; then
        yellow "The following required packages are missing:"
        for pkg in "${MISSING_PACKAGES[@]}"; do
            echo "  - $pkg"
        done
        read -p "Do you want to install these missing dependencies? (y/n): " confirm
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            echo "Updating apt and installing dependencies..."
            apt update && apt install -y "${MISSING_PACKAGES[@]}"
        else
            red "Installation aborted due to missing dependencies."
            return
        fi
    else
        green "All dependencies are already installed."
    fi

    echo "Fetching latest Nginx versions from nginx.org..."
    ngx_latest_stable=$(curl -s https://nginx.org/packages/debian/pool/nginx/n/nginx/ | grep '"nginx_' | sed -n "s/^.*\">nginx_\(.*\)\~.*$/\1/p" | sort -Vr | head -1 | cut -d'-' -f1)
    ngx_latest_mainline=$(curl -s https://nginx.org/packages/mainline/debian/pool/nginx/n/nginx/ | grep '"nginx_' | sed -n "s/^.*\">nginx_\(.*\)\~.*$/\1/p" | sort -Vr | head -1 | cut -d'-' -f1)

    while :
    do
        echo
        echo "Please choose the Nginx version you would like to install: "
        echo
        echo "  1. Stable (${ngx_latest_stable} with OpenSSL)"
        echo "  2. Mainline (${ngx_latest_mainline} with OpenSSL)"
        echo "  0. Back to main menu"
        echo
        read -p "Enter choice [0-2]: " ver_num
        case "${ver_num}" in
            1) download_source ${ngx_latest_stable}; break ;;
            2) download_source ${ngx_latest_mainline}; break ;;
            0) return ;;
            *) red "Error: Invalid number." ;;
        esac
    done

    SECONDS=0

    mkdir -p ${NGX_CONF_DIR}/conf.d ${NGX_LOG_DIR} ${NGX_PREFIX}

    cd ${BUILD_DIR}/nginx
    ./configure $NGX_CONFIGURE --with-openssl=${BUILD_DIR}/openssl
    
    echo "Compiling Nginx..."
    if ! make -j$CPU_COUNT; then
        red "Error: Compilation failed. Please check the logs above."
        exit 1
    fi

    if ! make install; then
        red "Error: Installation failed."
        exit 1
    fi

    if [ -f "${NGX_SBIN}" ]; then
        echo "Stripping Nginx binary to reduce size..."
        strip -s "${NGX_SBIN}"
    else
        red "Error: Nginx binary not found at ${NGX_SBIN} after installation."
        exit 1
    fi

    cat > /etc/systemd/system/nginx.service << EOF
[Unit]
Description=Nginx - High Performance Web Server
Documentation=https://nginx.org/en/docs/
After=network-online.target remote-fs.target nss-lookup.target
Wants=network-online.target
StartLimitIntervalSec=60s
StartLimitBurst=3

[Service]
Type=forking
PIDFile=${NGX_PID}
ExecStartPre=${NGX_SBIN} -t -q -c ${NGX_CONF}
ExecStart=${NGX_SBIN} -c ${NGX_CONF}
ExecStartPost=/bin/sleep 0.1
ExecReload=${NGX_SBIN} -s reload
ExecStop=/bin/kill -s TERM \$MAINPID
Restart=on-failure
RestartSec=5s
LimitNOFILE=65535
TimeoutStopSec=5
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOF

    echo "Creating symbolic link..."
    ln -sf "${NGX_SBIN}" /usr/local/bin/nginx
    green "\nSuccess! Nginx is installed at ${NGX_PREFIX}."
    green "Total: ${SECONDS} seconds"

    systemctl daemon-reload

    if systemctl is-active --quiet nginx; then
        echo "Nginx is already running. Performing a graceful restart..."
        systemctl restart nginx
    else
        echo "Starting Nginx for the first time..."
        systemctl enable nginx
        systemctl start nginx
    fi
    
    if [ $? -eq 0 ]; then
        green "Nginx is up and running."
        setup_logrotate
        echo "--------------------------------------"
        ${NGX_SBIN} -V
    else
        red "Nginx failed to start/restart! Check 'journalctl -xeu nginx.service' for details."
        exit 1
    fi
}

main() {
    [ "$EUID" -ne 0 ] && { red "This script must be run with sudo privileges."; exit 1; }
    [ ! -f /etc/debian_version ] && { red "Error: Only supports Debian/Ubuntu."; exit 1; }

    green "+------------------------------------------------------------+"
    green "| A tool for auto-compiling and installing the latest Nginx  |"
    green "| Author : ATP <https://atpx.com>                            |"
    green "| Github : https://github.com/scenery/my-scripts             |"
    green "+------------------------------------------------------------+"
    
    detect_existing_nginx || true

    echo
    green "  1. Install Nginx"
    yellow "  0. Exit"
    echo
    read -p "Enter choice [0-1]: " num
    case "${num}" in
        1) install_nginx ;;
        0) exit 0 ;;
        *) red "Error: Invalid number." ;;
    esac
}

main
