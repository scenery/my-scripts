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
    if [[ ! $newhostname =~ ^[a-z0-9][a-z0-9-]*(\.[a-z0-9][a-z0-9-]*)*$ ]]; then
        echo "Invalid hostname format. Please follow the rules."
        return
    fi

    hostnamectl set-hostname "$newhostname"
    echo "$newhostname" > /etc/hostname

    if grep -q "127.0.0.1" /etc/hosts; then
        sed -i "s/127.0.0.1.*/127.0.0.1   localhost $newhostname/" /etc/hosts
    else
        echo "127.0.0.1   localhost $newhostname" >> /etc/hosts
    fi
    if grep -q "::1" /etc/hosts; then
        sed -i "s/::1.*/::1         localhost ip6-localhost ip6-loopback $newhostname/" /etc/hosts
    fi

    green "Success, you will see the effect on the next session."
    echo "Back to menu..."
}

install_bbr() {
    local current_bbr_status=$(sysctl net.ipv4.tcp_congestion_control | awk '{print $3}')
    if [[ "$current_bbr_status" == "bbr" ]]; then
        yellow "TCP BBR has already been enabled, nothing to do."
        echo "Back to menu..."
        return
    fi

    local kernel_version=$(uname -r | cut -d- -f1)
    if [[ "$(echo -e "${kernel_version}\n4.9" | sort -rV | head -n 1)" != "${kernel_version}" ]]; then
        red "Your kernel version is lower than 4.9. Please run this script again after upgrading the kernel."
        echo "Back to menu..."
        return
    fi

    echo "The kernel version is greater than or equal to 4.9. Directly setting TCP BBR..."
    echo "net.core.default_qdisc = fq" >> /etc/sysctl.conf
    echo "net.ipv4.tcp_congestion_control = bbr" >> /etc/sysctl.conf
    sysctl -p >/dev/null 2>&1

    local new_bbr_status=$(sysctl net.ipv4.tcp_congestion_control | awk '{print $3}')
    if [[ "$new_bbr_status" == "bbr" ]]; then
        green "Setting TCP BBR completed successfully."
        echo "You can run 'sysctl net.ipv4.tcp_congestion_control' to check the congestion control algorithm in use."
    else
        red "Failed to enable TCP BBR. Please check the configuration in /etc/sysctl.conf"
    fi

    echo "Back to menu..."
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
            cat >> ~/.bashrc << 'EOF'

# Customize Bash Colors in Terminal Prompt
if [ -z "$PS1" ]; then
    return
fi

if [ "$(id -u)" -eq 0 ]; then
    PS1='\[\033[01;31m\]\u\[\033[01;33m\]@\[\033[01;36m\]\h:\[\033[01;33m\]\w\[\033[01;35m\]# \[\033[00m\]'
else
    PS1='\u@\h:\w\$ '
fi

alias ls='ls --color=auto'
alias ll='ls --color=auto -lAF'

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

set_timezone() {
    echo "Current timezone: "
    timedatectl show --property=Timezone --value
    echo
    echo "Please choose a timezone:"
    echo "1. Asia/Singapore"
    echo "2. Asia/Hong_Kong"
    echo "3. Asia/Shanghai"
    echo "4. America/Los_Angeles"
    echo "5. UTC"
    echo "6. Manually input timezone (e.g., Europe/London, Europe/Berlin, etc.)"

    read -p "Enter your choice [1-6]: " choice

    case $choice in
        1) timezone="Asia/Singapore" ;;
        2) timezone="Asia/Hong_Kong" ;;
        3) timezone="Asia/Shanghai" ;;
        4) timezone="America/Los_Angeles" ;;
        5) timezone="UTC" ;;
        6)
            echo "Please enter a valid timezone, following the format: Region/City"
            echo "Refer: https://en.wikipedia.org/wiki/List_of_tz_database_time_zones"
            read -p "Enter the timezone: " timezone
            ;;
        *)
            echo "Invalid choice, please try again."
            return 1
            ;;
    esac

    timedatectl set-timezone "$timezone"
    green "Timezone has been successfully set to $timezone."
    timedatectl
}

enable_ntp() {
    echo "Current NTP status: "
    timedatectl show --property=NTP --value
    echo "Setting up NTP..."

    if ! dpkg -l | grep -q systemd-timesyncd; then
        apt install systemd-timesyncd -y
        green "systemd-timesyncd installed successfully."
    else
        yellow "systemd-timesyncd is already installed."
    fi

    sed -i 's/^#\?NTP=.*/NTP=time.cloudflare.com time.google.com/' /etc/systemd/timesyncd.conf
    sed -i 's/^#\?FallbackNTP=.*/FallbackNTP=time.windows.com time.apple.com 0.debian.pool.ntp.org 1.debian.pool.ntp.org/' /etc/systemd/timesyncd.conf

    systemctl restart systemd-timesyncd
    green "NTP servers have been configured."
    echo "Configured NTP servers:"
    grep -E '^NTP=|^FallbackNTP=' /etc/systemd/timesyncd.conf
}

set_journal_log_size() {
    local default_size="500M"
    echo "This will update the 'SystemMaxUse' parameter in '/etc/systemd/journald.conf'."
    echo "The default value is ${default_size}. You can use units like M (megabytes), G (gigabytes), etc."

    echo -n "Enter the desired log size (or press Enter to use default ${default_size}): "
    read log_size

    if [ -z "$log_size" ]; then
        log_size=$default_size
    fi

    if [[ ! "$log_size" =~ ^[0-9]+[M|G]?$ ]]; then
        echo "Invalid input. Please enter a valid size (e.g., 500M, 1G)."
        return
    fi

    echo "Your 'SystemMaxUse' will be updated to '${log_size}'."
    echo -n "Do you want to continue? [Y/N]: "

    while :
    do
        read confirm
        case $confirm in
            [Yy][Ee][Ss]|[Yy]) 
                sed -i "s/^#SystemMaxUse=.*$/SystemMaxUse=${log_size}/" /etc/systemd/journald.conf
                if ! grep -q "^SystemMaxUse=" /etc/systemd/journald.conf; then
                    echo "SystemMaxUse=${log_size}" >> /etc/systemd/journald.conf
                fi
                systemctl restart systemd-journald
                green "Log size updated to ${log_size} and journald service restarted."
                break ;;
            [Nn][Oo]|[Nn])
                echo "No changes made. Back to menu..."
                break ;;
            * )
                echo -n "Invalid option, do you want to continue? [Y/N]: " ;;
        esac
    done
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
        green " 7. Set Timezone"
        green " 8. Enable NTP Servers"
        green " 9. Set Journal Log Max Size"
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
        7)  set_timezone ;;
        8)  enable_ntp ;;
        9)  set_journal_log_size ;;
        0)  echo "Bye~"
            sleep 1
            exit 0 ;;
        *)  red "Error: Invalid number." ;;
        esac
    done
}

# Run
main
