#!/bin/bash
# Written on 2022-01-11 by ATP for personal test
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

install_trojan_go() {
    SECONDS=0
    green "================Start Installing Trojan-Go==============="
    sleep 1
    apt install curl zip unzip -y
    mkdir /etc/trojan-go && cd /etc/trojan-go
    tag_name=`curl -s https://api.github.com/repos/p4gefau1t/trojan-go/releases/latest | grep tag_name | cut -f4 -d "\""`
    wget https://github.com/p4gefau1t/trojan-go/releases/download/$tag_name/trojan-go-linux-amd64.zip
    unzip trojan-go-linux-amd64.zip
    rm trojan-go-linux-amd64.zip
    touch server.json
    chmod +x trojan-go
    
cat > /lib/systemd/system/trojan-go.service <<-EOF
[Unit]
Description=Trojan-Go
Documentation=https://p4gefau1t.github.io/trojan-go/
After=network.target nss-lookup.target

[Service]
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
NoNewPrivileges=true
PIDFile=/etc/trojan-go/trojan-go.pid
ExecStart=/etc/trojan-go/trojan-go -config /etc/trojan-go/server.json
Restart=on-failure
RestartSec=10s
RestartPreventExitStatus=23
LimitNOFILE=infinity

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable trojan-go.service
    green "==============Trojan-Go Install Success=============="
    green "Version: ${tag}"
    green "Program Path: /etc/trojan-go/"
    green "Status: service trojan-go status"
    yellow "Total: $SECONDS seconds"
    yellow "Edit /etc/trojan-go/server.json before running!"
    green "====================================================="
}

main() {
    clear
    green "+---------------------------------------------------+"
    green "| Get the latest version of Trojan-Go               |"
    green "| Github : https://github.com/scenery/my-scripts    |"
    green "| **This script only supports Debian GNU/Linux**    |"
    green "+---------------------------------------------------+"
    echo
    green " 1. Install Trojan-Go"
    yellow " 0. Exit"
    echo
    read -p "Enter a number: " num
    case "$num" in
    1)
        install_trojan_go
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
