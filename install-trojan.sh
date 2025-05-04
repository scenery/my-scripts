#!/bin/bash
# Written on 2022-01-11
# Refactored on 2025-04-24
# Github: https://github.com/scenery/my-scripts

green(){ echo -e "\033[32m\033[01m$1\033[0m"; }
yellow(){ echo -e "\033[33m\033[01m$1\033[0m"; }
red(){ echo -e "\033[31m\033[01m$1\033[0m"; }

TROJAN_GO_DIR="/home/app/trojan-go"
TROJAN_RUST_DIR="/home/app/trojan-rust"

install_libs(){
    local pkgs=("$@")
    local miss=()
    for p in "${pkgs[@]}"; do
        if ! command -v "$p" &>/dev/null; then
            miss+=("$p")
        fi
    done
    if [ "${#miss[@]}" -gt 0 ]; then
        yellow "Installing missing packages: ${miss[*]}"
        apt update
        apt install -y "${miss[@]}"
    fi
}

get_latest_ver(){
    install_libs curl
    curl -s "https://api.github.com/repos/$1/releases/latest" \
      | grep -Po '"tag_name":\s*"\K([^"]+)'
}

get_installed_version() {
    local app_dir="$1"
    local app_name="$2"
    local version=""
    if [[ -x "${app_dir}/${app_name}" ]]; then
        if [[ "${app_name}" == "trojan-go" ]]; then
             version="$("${app_dir}/${app_name}" --version 2>&1 | grep -Po 'Trojan-Go[ ]*v?\K[0-9.]+' )"
        elif [[ "${app_name}" == "trojan_rust" ]]; then
             version="$("${app_dir}/${app_name}" --version 2>&1 | grep -Po 'Trojan Rust[ ]*v?\K[0-9.]+' )"
        fi
    fi
    echo "$version"
}

download_and_move() {
    local app_dir="$1"
    local app_name="$2"
    local repo="$3"
    local arch="$4"
    local temp_dir="$5"
    local latest_ver="$6"

    mkdir -p "${temp_dir}"
    local download_name
    local dl_url

    if [[ "${app_name}" == "trojan-go" ]]; then
        download_name="trojan-go.zip"
        dl_url="https://github.com/${repo}/releases/download/${latest_ver}/trojan-go-linux-${arch}.zip"
    else
        download_name="trojan_rust"
        dl_url="https://github.com/${repo}/releases/download/${latest_ver}/trojan_rust_linux_x86_64"
    fi

    echo "Downloading ${dl_url} ..."
    wget -qO "${temp_dir}/${download_name}" "${dl_url}"
    if [[ ! -s "${temp_dir}/${download_name}" ]]; then
        red "Download failed, aborting."
        exit 1
    fi

    echo "Moving ${app_name} to ${app_dir}/ ..."
    mkdir -p "${app_dir}"
    if [[ "${app_name}" == "trojan-go" ]]; then
        unzip -qo "${temp_dir}/${download_name}" -d "${temp_dir}"
        mv "${temp_dir}/${app_name}" "${app_dir}/${app_name}"
    else
        chmod +x "${temp_dir}/${app_name}"
        mv "${temp_dir}/${app_name}" "${app_dir}/${app_name}"
    fi
}

create_systemd_service() {
    local app_dir="$1"
    local app_name="$2"
    local service_name="$3"
    local service_description="$4"
    local service_documentation="$5"
    local config_file="$6"
    local run_user="$7"

    local service_config=""
    if [[ -n "$run_user" && "$run_user" != "root" ]]; then
        if ! id "$run_user" &>/dev/null; then
            yellow "User '$run_user' does not exist. Please make sure to create it later."
        fi
        service_config="User=${run_user}
Group=${run_user}
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
NoNewPrivileges=true
"
    else
        service_config=""
    fi

    cat > "/etc/systemd/system/${service_name}.service" <<-EOF
[Unit]
Description=${service_description}
Documentation=${service_documentation}
After=network.target nss-lookup.target

[Service]
Type=simple
${service_config}ExecStart=${app_dir}/${app_name} --config ${config_file}
LimitNOFILE=65536
Restart=on-failure
RestartSec=10s

[Install]
WantedBy=multi-user.target
EOF
}

config_new_install() {
    local app_dir="$1"
    local app_name="$2"
    local service_name="$3"
    local latest_ver="$4"
    local service_description="$5"
    local service_documentation="$6"
    local temp_dir="$7"

    # create config file
    local config_file="${app_dir}/server.json"

    if [[ ! -f "${config_file}" ]]; then
        if [[ "${app_name}" == "trojan-go" ]]; then
            mv "${temp_dir}/example/server.json" "${config_file}"
            chmod 644 "${config_file}"
        else
            cat > "${config_file}" <<-EOF
{
    "inbound": {
        "mode": "TCP",
        "protocol": "TROJAN",
        "address": "0.0.0.0",
        "port": 8081,
        "secret": "123123",
        "tls": {
            "cert_path": "/path/to/cert.pem",
            "key_path": "/path/to/key.pem"
        }
    },
    "outbound": {
        "mode": "DIRECT",
        "protocol": "DIRECT"
    }
}
EOF
        fi
    else
        yellow "Config file already exists at ${config_file}. No changes made."
    fi

    # create systemd service file
    echo
    echo "Please enter the user to run the ${service_name}.service"
    echo "* This user MUST have read access to your SSL certificate files."
    read -rp "Enter the user (default root): " run_user

    create_systemd_service "${app_dir}" "${app_name}" "${service_name}" "${service_description}" "${service_documentation}" "${config_file}" "${run_user}"

    systemctl daemon-reload
    systemctl enable "${service_name}.service"

    echo "The ${service_name}.service has been enabled."
    green "${app_name} installed successfully."
    yellow "Please configure ${config_file} before starting."
    echo "Then you can start the service with the following command:"
    echo "  systemctl start ${service_name}.service"
}

install_generic() {
    local app_dir="$1"
    local app_name="$2"
    local service_name="$3"
    local repo="$4"
    local arch="$5"
    local config_action="$6"
    local service_description="$7"
    local service_documentation="$8"

    local temp_dir="${app_dir}/temp"
    local latest_ver="$(get_latest_ver "${repo}")"
    local installed_ver="$(get_installed_version "${app_dir}" "${app_name}")"

    # install libs
    local required_libs="curl wget"
    if [[ "${app_name}" == "trojan-go" ]]; then
        required_libs="${required_libs} unzip"
    fi
    install_libs ${required_libs}

    # fresh new install or upgrade
    local action
    echo
    echo "Installed version: ${installed_ver:-none}"
    echo "Latest version on GitHub: ${latest_ver#v}"

    if [[ -z "${installed_ver}" ]]; then
        yellow "No installation detected."
        read -r -p "Do you want to install ${service_name} now? (y/n, default y): " confirm_install
        confirm_install=${confirm_install:-y}
        if [[ ! "$confirm_install" =~ ^[Yy]$ ]]; then
            yellow "Installation canceled. Exiting script."
            exit 0
        fi
        echo "Starting fresh install of ${latest_ver}..."
        action="install"
    elif [[ "${installed_ver}" != "${latest_ver#v}" ]]; then
        green "Upgrade available: ${latest_ver} (installed: ${installed_ver})"
        read -r -p "Do you want to upgrade now? (y/n, default y): " confirm_upgrade
        confirm_upgrade=${confirm_upgrade:-y}
        if [[ ! "$confirm_upgrade" =~ ^[Yy]$ ]]; then
            yellow "Upgrade canceled. No changes made."
            exit 0
        fi
        action="upgrade"
    else
        green "Already up-to-date."
        exit 0
    fi

    # download target program and move to installation folder
    download_and_move "${app_dir}" "${app_name}" "${repo}" "${arch}" "${temp_dir}" "${latest_ver}"

    if [[ "${action}" == "install" ]]; then
        config_new_install "${app_dir}" "${app_name}" "${service_name}" "${latest_ver}" "${service_description}" "${service_documentation}" "${temp_dir}"
    elif [[ "${action}" == "upgrade" ]]; then
        green "${app_name} upgraded successfully."
        if systemctl is-active --quiet "${service_name}.service"; then
            systemctl restart "${service_name}.service"
            echo "The ${service_name}.service has been restarted."
        else
            yellow "The ${service_name}.service is not running."
            echo "You can start the service with the following command:"
            echo "  systemctl start ${service_name}.service"
        fi
    fi

    # clean up temp dir
    rm -rf "${temp_dir}"
    exit 0
}

install_trojan_go() {
    local arch
    case "$(uname -m)" in
        x86_64)  arch="amd64" ;;
        aarch64) arch="armv8" ;;
        *) red "Error: Unsupported architecture: $(uname -m)"; exit 1 ;;
    esac
    local app_dir=$TROJAN_GO_DIR
    local app_name="trojan-go"
    local service_name="trojan-go"
    local config_action="copy"
    local service_description="Trojan-Go"
    local service_documentation="https://p4gefau1t.github.io/trojan-go/"
    local repo
    echo
    echo "Please select the source:"
    while true; do
        echo
        echo " 1) Original  (p4gefau1t/trojan-go)"
        echo " 2) Fork      (fregie/trojan-go)"
        echo " 0) Return"
        echo
        read -rp "Enter a number (1/2/0): " num
        case "$num" in
            0) yellow "Back to main menu."; return ;;
            1) repo="p4gefau1t/trojan-go"; break ;;
            2) repo="fregie/trojan-go"; break ;;
            *) red "Invalid input. Please enter 1, 2, or 0." ;;
        esac
    done

    install_generic "${app_dir}" "${app_name}" "${service_name}" "${repo}" "${arch}" "${config_action}" "${service_description}" "${service_documentation}"
}

install_trojan_rust() {
    local arch="$(uname -m)"
    if [[ "${arch}" != "x86_64" ]]; then
        red "Error: TrojanRust only supports x86_64 architecture."
        exit 1
    fi

    local app_dir=$TROJAN_RUST_DIR
    local app_name="trojan_rust"
    local service_name="trojan-rust"
    local repo="cty123/TrojanRust"
    local config_action="generate"
    local service_description="TrojanRust"
    local service_documentation="https://github.com/cty123/TrojanRust"

    install_generic "${app_dir}" "${app_name}" "${service_name}" "${repo}" "${arch}" "${config_action}" "${service_description}" "${service_documentation}"
}


main(){
    if [[ $(id -u) != 0 ]]; then
        echo "Please run this script as root."
        exit 1
    fi

    green "+------------------------------------------------+"
    green "| Get the latest version of Trojan-Go/TrojanRust |"
    green "| Github : https://github.com/scenery/my-scripts |"
    green "| **This script only supports Debian GNU/Linux** |"
    green "+------------------------------------------------+"
    while true; do
        echo
        echo " 1. Install Trojan-Go"
        echo " 2. Install TrojanRust"
        echo " 0. Exit"
        echo
        read -rp "Enter a number (1/2/0): " num
        case "$num" in
            1) install_trojan_go ;;
            2) install_trojan_rust ;;
            0) echo "Bye~"; exit 0 ;;
            *) red "Invalid input. Please enter 1, 2, or 0." ;;
        esac
    done
}

main
