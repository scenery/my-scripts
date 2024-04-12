#!/bin/bash
# Written by ATP on 2022-03-21
# Website: https://atpx.com
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
blue(){
    echo -e "\033[34m\033[01m$1\033[0m"
}

change_hostname() {
    echo
    echo "Current hostname: "
    cat /etc/hostname
    echo
    echo "Please note: "
    echo "1. The host name can only contain numbers 0-9, letters a-za-z, hyphens – and. Nothing else is allowed."
    echo "2. Hyphens are not allowed at the beginning and end of the host name."
    echo "3. Use lower case letters instead of upper case letters."
    echo
    read -p "Input a new hostname: " newhostname
    hostnamectl set-hostname $newhostname
    green "Success, you will see the effect on the next connection."
    echo "Back to menu..."
}

check_bbr_status() {
    local param=$(sysctl net.ipv4.tcp_congestion_control | awk '{print $3}')
    if [[ x"${param}" == x"bbr" ]]; then
        return 0
    else
        return 1
    fi
}

# https://www.xmodulo.com/compare-two-version-numbers.html
version_ge(){
    test "$(echo "$@" | tr " " "\n" | sort -rV | head -n 1)" == "$1"
}

check_kernel_version() {
    local kernel_version=$(uname -r | cut -d- -f1)
    if version_ge ${kernel_version} 4.9; then
        return 0
    else
        return 1
    fi
}

sysctl_config() {
    echo "net.core.default_qdisc = fq" >> /etc/sysctl.conf
    echo "net.ipv4.tcp_congestion_control = bbr" >> /etc/sysctl.conf
    sysctl -p >/dev/null 2>&1
}

install_bbr() {
    if check_bbr_status; then
        echo
        yellow "TCP BBR has already been enabled, nothing to do."
        echo "Back to menu..."
    elif check_kernel_version; then
        echo
        echo "The kernel version is greater than 4.9, directly setting TCP BBR..."
        sysctl_config
        green "Setting TCP BBR completed"
        echo "You can run 'sysctl net.ipv4.tcp_congestion_control' to check the congestion control algorithm in use."
        echo "Back to menu..."
    fi
}

change_ssh_port() {
    echo
    echo -n "Please enter the SSH port [1024-65535]: "
    while : 
    do
    read SSHPORT
        if [[ "$SSHPORT" =~ ^[0-9]{2,5}$ || "$SSHPORT" = 22 ]]; then
            if [[ "$SSHPORT" -ge 1024 && "$SSHPORT" -le 65535 || "$SSHPORT" = 22 ]]; then
                # Create backup of current SSH config
                NOW=$(date +"%Y_%m_%d-%H_%M")
                cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup.$NOW
                # Apply changes to sshd_config
                sed -i -e "/Port /c\Port $SSHPORT" /etc/ssh/sshd_config
                # Restart SSH service
                systemctl restart sshd.service
                echo
                green "The SSH port has been changed to $SSHPORT."
                green "Please login using new port to test BEFORE ending this session."
                echo "Backup file: '/etc/ssh/sshd_config.backup.$NOW'"
                echo "Back to menu..."
                break
            else
                red "Invalid port: must be 22, or between 1024 and 65535."
                echo -n "Please enter the SSH port [1024-65535]: "
            fi
        else
            red "Invalid port: must be numeric!"
            echo -n "Please enter the SSH port [1024-65535]: "
        fi
    done
}

install_nginx() {
    if [ ! "$(command -v curl)" ]; then
        apt-get install curl -y
    fi
    if [ -d /etc/nginx ]; then
        echo -n "Nginx already installed, still continue? [Y/N]: "
        while : 
        do
        read gonginx
        case $gonginx in
            [Yy][Ee][Ss]|[Yy]) 
                bash <(curl -Ls https://raw.githubusercontent.com/scenery/my-scripts/main/install-nginx.sh) -i 
                break ;;
            [Nn][Oo]|[Nn]) 
                break ;;
            * ) echo -n "Invalid option, still continue? [Y/N]: " ;;
        esac
        done
    else
        bash <(curl -Ls https://raw.githubusercontent.com/scenery/my-scripts/main/install-nginx.sh) -i
    fi
    echo "Back to menu..."
}

ssh_keepalive() {
    echo "Your 'sshd_config' file will be update to the following parameters:"
    echo "ClientAliveInterval 45"
    echo "ClientAliveCountMax 5"
    echo -n "Still continue? [Y/N]: "
    while : 
    do
    read goupdate
    case $goupdate in
        [Yy][Ee][Ss]|[Yy]) 
            sed -i "/#TCPKeepAlive /c\TCPKeepAlive yes" /etc/ssh/sshd_config
            sed -i "/#ClientAliveInterval /c\ClientAliveInterval 45" /etc/ssh/sshd_config
            sed -i "/#ClientAliveCountMax /c\ClientAliveCountMax 5" /etc/ssh/sshd_config
            systemctl restart sshd.service
            break ;;
        [Nn][Oo]|[Nn]) 
            break ;;
        * ) echo -n "Invalid option, still continue? [Y/N]: " ;;
    esac
    done
    echo "Back to menu..."
}

colorizing_bash() {
    echo "Customize Bash Colors in Linux Terminal Prompt"
    echo "This operation will modify your ‘~/.bashrc’ file"
    echo -n "Still continue? [Y/N]: "
    while : 
    do
    read goupdate
    case $goupdate in
        [Yy][Ee][Ss]|[Yy]) 
            cat >> ~/.bashrc << EOF

# Customize Bash Colors in Terminal Prompt
if [ -z "\$PS1" ]; then
    return
fi
alias ls='ls --color=auto'
alias ll='ls --color=auto -lAF'
PS1='\[\033[01;31m\]\u\[\033[01;33m\]@\[\033[01;36m\]\h:\[\033[01;33m\]\w\[\033[01;35m\]\$ \[\033[00m\]'
EOF
            source ~/.bashrc
            break ;;
        [Nn][Oo]|[Nn]) 
            break ;;
        * ) echo -n "Invalid option, still continue? [Y/N]: " ;;
    esac
    done
    echo "Back to menu..."
}

main() {
    # Check if user is root
    if [ $(id -u) != "0" ]; then
        red "Error: You must be root to run this script."
        exit 1
    fi   
    if [ ! -f /etc/debian_version ]; then
        red "Error: This script only supports Debian GNU/Linux Operating System."
        exit 1
    fi
    clear
    green "+---------------------------------------------------+"
    green "| Initialization Script for Managing Servers        |"
    green "| Written by ATP <https://atpx.com>                 |"
    green "| Github : https://github.com/scenery/my-scripts    |"
    green "+---------------------------------------------------+"
    while :
    do
        echo
        green " 1. Change Hostname"
        green " 2. Change SSH Port"
        green " 3. Enable TCP BBR"
        green " 4. Install Nginx"
        green " 5. SSH Keep Alive"
        green " 6. Colorizing Bash Prompt"
        yellow " 0. Exit"
        echo
        read -p "Enter your menu choice [0-6]: " num
        case "$num" in
        1)  change_hostname ;;
        2)  change_ssh_port ;;
        3)  install_bbr ;;
        4)  install_nginx ;;
        5)  ssh_keepalive ;;
        6)  colorizing_bash ;;
        0)  echo "Bye~"
            sleep 1
            exit 0 ;;
        *)  red "Error: Invalid number." ;;
        esac
    done
}

# Run
main
