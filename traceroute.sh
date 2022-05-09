  
#!/bin/bash
# A simple trace route test tool
# Powered by Besttrace (ipip.net)
# Written on 2021-09-19 by ATP
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

install_besttrace() {
    apt install wget zip unzip -y
    mkdir /root/traceroute-temp && cd /root/traceroute-temp
    wget https://cdn.ipip.net/17mon/besttrace4linux.zip
    unzip besttrace4linux.zip
    chmod +x besttrace
}

separate() {
    printf "%-70s\n" "-" | sed 's/\s/-/g'
}

run_trace() {
    clear
    echo "============================Start traceroute============================"
    ip_list=(14.215.116.1 101.95.120.109 123.125.81.6 58.250.0.1 211.138.180.2 211.137.82.4)
    ip_addr=(广州电信-TCP 上海电信-TCP 北京联通-TCP 深圳联通-TCP 安徽移动-TCP 成都移动-TCP)

    for i in {0..5}
    do
        echo ${ip_addr[$i]}
        ./besttrace -T -q 1 ${ip_list[$i]}
        separate
    done
}

clean_up() {
    if [ ! -d "/root/traceroute-temp" ]
    then
        red "Path '/root/traceroute-temp' does not exist, if you renamed the folder, please delete it manually."
    else
        rm -rf /root/traceroute-temp
        green "Clean up success!"
    fi
}

main() {
    green "+-------------------------------------------------+"
    green "| Traceroute to China                             |"
    green "| Author : Atp <hi@zatp.com>                      |"
    green "| Github: https://github.com/scenery/my-scripts   |"
    green "+-------------------------------------------------+"
    echo
    green " 1. Run traceroute"
    red " 2. Clean up all files"
    yellow " 0. Exit"
    echo
    read -p "Enter a number: " num
    case "$num" in
    1)
        if [ ! -f "/root/traceroute-temp/besttrace" ]
        then
            install_besttrace
        else
            cd /root/traceroute-temp
        fi
        run_trace
        ;;
    2)
        clean_up
        ;;
    0)
        exit 1
        ;;
    *)
        red "Invalid number!"
        sleep 2s
        main
        ;;
    esac
}

main
