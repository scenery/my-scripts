#!/bin/bash
# Written on 2022-01-11
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

trojan_go_location=/home/trojan/trojan-go
trojan_rust_location=/home/trojan/trojan-rust

install_trojan_go() {
    SECONDS=0
    green "================Start Installing Trojan-Go==============="
    green "Select the version you want to install: "
    green "1: Trojan-Go Original (https://github.com/p4gefau1t/trojan-go)"
    green "2: Trojan-Go Fork (https://github.com/fregie/trojan-go)"
    read -p "Enter your choice: " input
    if [ $input -eq 1 ]; then
        maintainer=p4gefau1t
    elif [ $input -eq 2 ]; then
        maintainer=fregie
    else
        red "Invalid input, please enter 1 or 2"
        red "Aborted, Back to menu..."
        sleep 2
        main
    fi
    apt install curl zip unzip -y
    mkdir -p $trojan_go_location && cd $trojan_go_location
    tag_name=`curl -s https://api.github.com/repos/$maintainer/trojan-go/releases/latest | grep tag_name | cut -f4 -d "\""`
    wget https://github.com/$maintainer/trojan-go/releases/download/$tag_name/trojan-go-linux-amd64.zip
    unzip trojan-go-linux-amd64.zip
    rm trojan-go-linux-amd64.zip
    cp $trojan_go_location/example/server.json $trojan_go_location
    chmod +x trojan-go
    echo "Installing trojan-go systemd service..."
    cat > /etc/systemd/system/trojan-go.service <<-EOF
[Unit]
Description=Trojan-Go
Documentation=https://p4gefau1t.github.io/trojan-go/
After=network.target nss-lookup.target

[Service]
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
NoNewPrivileges=true
PIDFile=$trojan_go_location/trojan-go.pid
ExecStart=$trojan_go_location/trojan-go -config $trojan_go_location/server.json
Restart=on-failure
RestartSec=10s
RestartPreventExitStatus=23
LimitNOFILE=infinity

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable trojan-go.service
    green "Done!"
    green "Version: $tag_name"
    green "Program Path: $trojan_go_location"
    green "Status: service trojan-go status"
    yellow "Total: $SECONDS seconds"
    yellow "Edit $trojan_go_location/server.json before running!"
}

install_trojan_rust() {
    SECONDS=0
    green "================Start Installing TrojanRust==============="
    sleep 1
    apt install curl -y
    mkdir -p $trojan_rust_location && cd $trojan_rust_location
    tag_name=`curl -s https://api.github.com/repos/cty123/TrojanRust/releases/latest | grep tag_name | cut -f4 -d "\""`
    wget -O trojan_rust https://github.com/cty123/TrojanRust/releases/download/$tag_name/trojan_rust_linux_x86_64
    cat > $trojan_rust_location/server.json <<-EOF
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
    chmod +x trojan_rust
    echo "Installing trojan-rust systemd service..."
    cat > /etc/systemd/system/trojan-rust.service <<-EOF
[Unit]
Description=TrojanRust
Documentation=https://github.com/cty123/TrojanRust
After=network.target nss-lookup.target

[Service]
Type=simple
ExecStart=$trojan_rust_location/trojan_rust --config $trojan_rust_location/server.json
ExecReload=/bin/kill -HUP \$MAINPID
LimitNOFILE=51200
Restart=on-failure
RestartSec=10s
RestartPreventExitStatus=23

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable trojan-rust.service
    green "Done!"
    green "Version: $tag_name"
    green "Program Path: $trojan_rust_location"
    green "Status: service trojan-rust status"
    yellow "Total: $SECONDS seconds"
    yellow "Edit $trojan_rust_location/server.json before running!"
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
    green "| Get the latest version of Trojan-Go/TrojanRust    |"
    green "| Github : https://github.com/scenery/my-scripts    |"
    green "| **This script only supports Debian GNU/Linux**    |"
    green "+---------------------------------------------------+"
    echo
    green " 1. Install Trojan-Go"
    green " 2. Install TrojanRust"
    yellow " 0. Exit"
    echo
    read -p "Enter a number: " num
    case "$num" in
        1)
            install_trojan_go
            ;;
        2)
            install_trojan_rust
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
