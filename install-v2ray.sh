#!/bin/bash
# Written on 2024-03-20
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

v2ray_location=/home/app/v2ray

install_v2ray() {
    SECONDS=0
    green "================Start Installing V2Ray==============="
    apt install curl zip unzip -y
    mkdir -p $v2ray_location && cd $v2ray_location
    tag_name=`curl -s https://api.github.com/repos/v2fly/v2ray-core/releases/latest | grep tag_name | cut -f4 -d "\""`
    wget https://github.com/v2fly/v2ray-core/releases/download/$tag_name/v2ray-linux-64.zip
    unzip v2ray-linux-64.zip
    rm v2ray-linux-64.zip
    chmod +x v2ray
    echo "Installing v2ray systemd service..."
    cat > /etc/systemd/system/v2ray.service <<-EOF
[Unit]
Description=V2Ray Service
Documentation=https://www.v2fly.org/
After=network.target nss-lookup.target

[Service]
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
NoNewPrivileges=true
ExecStart=$v2ray_location/v2ray run -c $v2ray_location/config.json -format jsonv5
Restart=on-failure
RestartPreventExitStatus=23

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    systemctl enable v2ray.service
    green "Done!"
    green "Version: $tag_name"
    green "Program Path: $v2ray_location"
    green "Status: service v2ray status"
    yellow "Total: $SECONDS seconds"
    yellow "Edit $v2ray_location/config.json before running!"
}

upgrade_v2ray() {
    SECONDS=0
    green "================Start Upgrading V2Ray==============="
    cd $v2ray_location || exit
    tag_name=`curl -s https://api.github.com/repos/v2fly/v2ray-core/releases/latest | grep tag_name | cut -f4 -d "\""`
    wget https://github.com/v2fly/v2ray-core/releases/download/$tag_name/v2ray-linux-64.zip
    unzip -o v2ray-linux-64.zip -x config.json  # Exclude config.json
    rm v2ray-linux-64.zip
    chmod +x v2ray
    green "Upgrade completed!"
    green "New Version: $tag_name"
    yellow "Total: $SECONDS seconds"
    yellow "You can run the following command to restart the V2Ray service:"
    echo "systemctl restart v2ray.service"
}

main() {
    if [[ $(id -u) != 0 ]]; then
        echo "Please run this script as root."
        exit 1
    fi
    if [[ $(uname -m 2> /dev/null) != x86_64 ]]; then
        echo "Please run this script on x86_64 machine."
        exit 1
    fi
    clear
    green "+---------------------------------------------------+"
    green "| Install the latest version of V2Ray               |"
    green "| Github : https://github.com/scenery/my-scripts    |"
    green "| **This script only supports Debian GNU/Linux**    |"
    green "+---------------------------------------------------+"
    echo
    green " 1. Install V2Ray"
    green " 2. Upgrade V2Ray"
    yellow " 0. Exit"
    echo
    read -p "Enter a number: " num
    case "$num" in
        1)
            install_v2ray
            ;;
        2)
            upgrade_v2ray
            ;;
        0)
            exit 1 
            ;;
        *)
            clear
            red "Invalid number!"
            sleep 1s
            main
            ;;
    esac
}

# Run
main
