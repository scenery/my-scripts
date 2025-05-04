#!/bin/bash
# Written by ATP on 2022-03-21
# Website: https://atpx.com
# Github: https://github.com/scenery/my-scripts

green(){ echo -e "\033[32m\033[01m$1\033[0m"; }
red(){ echo -e "\033[31m\033[01m$1\033[0m"; }
yellow(){ echo -e "\033[33m\033[01m$1\033[0m"; }
blue(){ echo -e "\033[34m\033[01m$1\033[0m"; }

confirm() {
    local prompt="${1:-Are you sure? (y/n, default y): }"
    local response
    while true; do
        read -rp "$prompt" response
        response=${response:-y}
        case "$response" in
            [Yy][Ee][Ss]|[Yy]) return 0 ;;
            [Nn][Oo]|[Nn]) return 1 ;;
            *) red "Invalid option. Please enter yes or no." ;;
        esac
    done
}

install_common_packages() {
    echo "Checking for common packages: vim wget mtr-tiny net-tools dnsutils"
    packages=(vim wget mtr-tiny net-tools dnsutils)
    to_install=()
    for pkg in "${packages[@]}"; do
        if ! dpkg -s "$pkg" &>/dev/null; then
            to_install+=("$pkg")
        fi
    done

    if [ ${#to_install[@]} -eq 0 ]; then
        yellow "All common packages are already installed."
        return
    fi

    echo "The following packages are missing: ${to_install[*]}"
    if confirm "Do you want to install them? (y/n, default y): "; then
        apt update && apt install -y "${to_install[@]}"
        if [ $? -eq 0 ]; then
            green "Common packages installed successfully."
        else
            red "Failed to install some common packages."
        fi
    else
        yellow "Installation cancelled."
        return
    fi
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
}

change_ssh_port() {
    while :; do
        echo
        read -rp "Please enter the SSH port [1024-65535, or 22]: " SSHPORT
        if [[ "$SSHPORT" =~ ^[0-9]+$ ]] && { [[ "$SSHPORT" -eq 22 ]] || [[ "$SSHPORT" -ge 1024 && "$SSHPORT" -le 65535 ]]; }; then
            if grep -qE "^\s*#?\s*Port\s+[0-9]+" /etc/ssh/sshd_config; then
                echo "You entered port: $SSHPORT"
                if confirm "Do you want to change the SSH port to $SSHPORT? (y/n, default y): "; then
                    sed -i -E "s|^\s*#?\s*Port\s+[0-9]+|Port $SSHPORT|" /etc/ssh/sshd_config
                    systemctl restart sshd.service
                    echo
                    green "The SSH port has been changed to $SSHPORT."
                    blue "Please login using the new port to test BEFORE ending this session."
                    break
                else
                    yellow "Change aborted by user."
                fi
            else
                yellow "No matching Port line found in sshd_config. Change aborted."
            fi
        else
            red "Invalid port: must be 22, or between 1024 and 65535."
        fi
    done
}

add_ssh_key() {
    echo "Enter your ed25519 public key:" 
    read -r pubkey
    if [[ "$pubkey" =~ ^ssh-ed25519[[:space:]]+[A-Za-z0-9+/]+=*(?:[[:space:]].*)?$ ]]; then
        mkdir -p /root/.ssh
        chmod 700 /root/.ssh
        echo "$pubkey" >> /root/.ssh/authorized_keys
        chmod 600 /root/.ssh/authorized_keys
        green "Public key added to /root/.ssh/authorized_keys"

        if confirm "Disable password authentication? (y/n, default y): "; then
            sed -i 's/^#\?PubkeyAuthentication.*$/PubkeyAuthentication yes/' /etc/ssh/sshd_config
            sed -i 's/^#\?PasswordAuthentication.*$/PasswordAuthentication no/' /etc/ssh/sshd_config
            systemctl restart sshd.service
            green "Password authentication disabled, PubkeyAuthentication enabled."
        else
            yellow "Password authentication left unchanged."
        fi
    else
        red "Invalid ed25519 public key format."
    fi
}

install_ufw() {
    if ! command -v ufw &>/dev/null; then
        green "Installing UFW..."
        apt update && apt install -y ufw
        if [ $? -ne 0 ]; then
            red "Failed to install UFW."
            return
        fi
        green "UFW installed."
    else
        yellow "UFW is already installed."
        ufw status verbose
        return
    fi

    echo "Setting default rules..."
    echo "  deny incoming"
    echo "  allow outgoing"
    if confirm "Apply default rules? (y/n, default y): "; then
        ufw default deny incoming
        ufw default allow outgoing
        green "Default rules applied."
    else
        yellow "No default rules applied."
        yellow "** You should set default rules first. **"
        return
    fi

    echo
    echo "You can specify which ports to allow through the firewall."
    echo "Examples:"
    echo "  - To allow both TCP and UDP for a port, just enter the port number:"
    echo "    22 443"
    echo "  - To allow only TCP or only UDP, specify the protocol:"
    echo "    53/udp 80/tcp"
    echo "Separate multiple ports with spaces."
    echo
    echo "Choose port opening mode:"
    echo "1) Open specified ports for all"
    echo "2) Open specified ports for target IP only"
    read -rp "Select an option [1/2]: " mode
    case "$mode" in
        1)
            read -rp "Enter ports to allow: " ports 
            client_ip="" ;;
        2)
            read -rp "Enter IP address to allow: " client_ip
            read -rp "Enter ports for $client_ip (e.g. 22 80/tcp): " ports ;;
        *)
            red "Invalid option. Please enter 1 or 2."; return ;;
    esac

    # Preprocess and validate ports
    local invalid_count=0
    declare -a rules=()
    for p in $ports; do
        if [[ "$p" =~ ^([0-9]+)(/([a-zA-Z]+))?$ ]]; then
            port="${BASH_REMATCH[1]}"
            proto="${BASH_REMATCH[3]}"
            if [ -n "$proto" ]; then
                proto_lower="${proto,,}"
                if [[ "$proto_lower" != "tcp" && "$proto_lower" != "udp" ]]; then
                    red "Invalid protocol in: $p"; invalid_count=$((invalid_count+1)); continue
                fi
            fi

            if [ -n "$client_ip" ]; then
                if [ -n "$proto" ]; then
                    rules+=("ufw allow from $client_ip to any port $port proto $proto_lower")
                else
                    rules+=("ufw allow from $client_ip to any port $port")
                fi
            else
                if [ -n "$proto" ]; then
                    rules+=("ufw allow ${port}/${proto_lower}")
                else
                    rules+=("ufw allow $port")
                fi
            fi
        else
            red "Invalid port format: $p"; invalid_count=$((invalid_count+1))
        fi
    done
    if [ $invalid_count -gt 0 ]; then
        red "Aborting due to invalid port entries."
        return
    fi

    echo
    echo "The following UFW rules will be added:"
    for rule in "${rules[@]}"; do
        echo "  $rule"
    done
    echo
    if confirm "Apply these rules? (y/n, default y): "; then
        for rule in "${rules[@]}"; do
            $rule
        done
        ufw enable
    else
        yellow "Configuration cancelled."
        return
    fi
}

keep_ssh_alive() {
    echo "Your 'sshd_config' file will be update to the following parameters:"
    echo "ClientAliveInterval 45"
    echo "ClientAliveCountMax 5"
    if confirm "Still continue?? (y/n, default y): "; then
        sed -i "/#TCPKeepAlive /c\TCPKeepAlive yes" /etc/ssh/sshd_config
        sed -i "/#ClientAliveInterval /c\ClientAliveInterval 45" /etc/ssh/sshd_config
        sed -i "/#ClientAliveCountMax /c\ClientAliveCountMax 5" /etc/ssh/sshd_config
        systemctl restart sshd.service
    else
        yellow "Configuration cancelled."
        return
    fi
}

optimize_tcp() {
    local sysctl_conf="/etc/sysctl.conf"
    local current_bbr_status=$(sysctl net.ipv4.tcp_congestion_control | awk '{print $3}')

    if [[ "$current_bbr_status" == "bbr" ]]; then
        yellow "TCP BBR has already been enabled."
    else
        local kernel_version=$(uname -r | cut -d- -f1)
        if [[ "$(echo -e "${kernel_version}\n4.9" | sort -rV | head -n 1)" != "${kernel_version}" ]]; then
            red "Your kernel version is lower than 4.9. Please upgrade the kernel first."
            return
        fi

        echo "Enabling TCP BBR..."
        sed -i '/^net\.core\.default_qdisc/d' "$sysctl_conf"
        sed -i '/^net\.ipv4\.tcp_congestion_control/d' "$sysctl_conf"
        echo "net.core.default_qdisc = fq" >> "$sysctl_conf"
        echo "net.ipv4.tcp_congestion_control = bbr" >> "$sysctl_conf"
        sysctl -p >/dev/null 2>&1

        local new_bbr_status=$(sysctl net.ipv4.tcp_congestion_control | awk '{print $3}')
        if [[ "$new_bbr_status" == "bbr" ]]; then
            green "TCP BBR has been successfully enabled."
        else
            red "Failed to enable TCP BBR."
            return
        fi
    fi

    if ! confirm "Do you want to optimize TCP buffer settings? (y/n, default y): "; then
        yellow "Skipped TCP buffer optimization."
        return
    fi

    echo
    echo "TCP buffer size is typically calculated based on the Bandwidth-Delay Product (BDP):"
    echo "  BDP = Bandwidth (bits/sec) × RTT (sec) ÷ 8"
    echo "For example, 1Gbps bandwidth with 200ms RTT gives:"
    echo "  1,000,000,000 × 0.2 ÷ 8 = 25MB"
    echo
    echo "Recommended profiles for 1Gbps bandwidth:"
    echo " 1) 40ms latency  → Max buffer: 8MB"
    echo " 2) 80ms latency  → Max buffer: 16MB"
    echo " 3) 120ms latency → Max buffer: 24MB"
    echo " 4) 160ms latency → Max buffer: 32MB"
    echo " 5) 200ms latency → Max buffer: 40MB"
    echo " 6) Manual input"
    echo " 0) Cancel"
    echo
    echo "* Note: tcp_adv_win_scale is set to 1"
    echo "  Actual TCP window ≈ Max buffer / 2"
    read -rp "Choose an option [0-6]: " choice

    local rmem_max wmem_max tcp_rmem tcp_wmem max_mb max_bytes
    case "$choice" in
        1) max_bytes=8388608 ;;
        2) max_bytes=16777216 ;;
        3) max_bytes=25165824 ;;
        4) max_bytes=33554432 ;;
        5) max_bytes=41943040 ;;
        6)
            while true; do
                read -rp "Enter max TCP buffer size (e.g. 32M): " input
                if [[ "$input" =~ ^([0-9]+)[Mm]$ ]]; then
                    max_mb="${BASH_REMATCH[1]}"
                    max_bytes=$((max_mb * 1024 * 1024))
                    break
                else
                    echo "Invalid format. Please enter a number followed by 'M', e.g. 16M, 32M."
                fi
            done ;;
        0) yellow "Cancelled TCP buffer optimization."; return ;;
        *) red "Invalid selection."; return ;;
    esac

    rmem_max=$max_bytes
    wmem_max=$max_bytes
    tcp_rmem="4096 87380 $max_bytes"
    tcp_wmem="4096 16384 $max_bytes"

    sed -i '/# BEGIN: Optimized TCP buffer/,/# END: Optimized TCP buffer/d' "$sysctl_conf"

    echo "Applying changes to: $sysctl_conf"
    sed -i '/^net\.core\.\(rmem_max\|wmem_max\)[[:space:]]*=.*/s/^/#/' "$sysctl_conf"
    sed -i '/^net\.ipv4\.\(tcp_rmem\|tcp_wmem\|tcp_sack\|tcp_timestamps\|tcp_window_scaling\|tcp_adv_win_scale\)[[:space:]]*=.*/s/^/#/' "$sysctl_conf"

    {
        echo "# BEGIN: Optimized TCP buffer"
        echo "net.ipv4.tcp_sack = 1"
        echo "net.ipv4.tcp_fack = 1"
        echo "net.ipv4.tcp_timestamps = 1"
        echo "net.ipv4.tcp_mtu_probing = 1"
        echo "net.ipv4.tcp_window_scaling = 1"
        echo "net.ipv4.tcp_adv_win_scale = 1"
        echo "net.ipv4.tcp_moderate_rcvbuf = 1"
        echo "net.core.rmem_max = $rmem_max"
        echo "net.core.wmem_max = $wmem_max"
        echo "net.ipv4.tcp_rmem = $tcp_rmem"
        echo "net.ipv4.tcp_wmem = $tcp_wmem"
        echo "# END: Optimized TCP buffer"
    } >> "$sysctl_conf"

    sysctl -p && green "TCP buffer settings applied successfully."
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
    read -rp "Enter your choice [1-6]: " choice
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
        *) echo "Invalid choice, please try again."; return 1 ;;
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
    if confirm "Still continue? (y/n, default y): "; then
        sed -i "s/^#SystemMaxUse=.*$/SystemMaxUse=${log_size}/" /etc/systemd/journald.conf
        if ! grep -q "^SystemMaxUse=" /etc/systemd/journald.conf; then
            echo "SystemMaxUse=${log_size}" >> /etc/systemd/journald.conf
        fi
        systemctl restart systemd-journald
        green "Log size updated to ${log_size} and journald service restarted."
    else
        yellow "Configuration cancelled."
        return
    fi
}

colorize_bash() {
    echo "Customize Bash Colors in Linux Terminal Prompt"
    echo "This operation will modify your '~/.bashrc' file"
    if confirm "Still continue? (y/n, default y): "; then
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
        green "Configuration complete. Changes will take effect in the next SSH session."
    else
        yellow "Configuration cancelled."
    fi
}

install_nginx() {
    if ! command -v nginx &>/dev/null; then
        bash <(curl -Ls https://raw.githubusercontent.com/scenery/my-scripts/main/install-nginx.sh) -i
    else
        if confirm "Nginx already installed, still continue? (y/n, default y): "; then
            bash <(curl -Ls https://raw.githubusercontent.com/scenery/my-scripts/main/install-nginx.sh) -i
        else
            yellow "Installation cancelled."
            return
        fi
    fi
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
    while :; do
        echo
        green "  1. Install Common Packages"
        green "  2. Change Hostname"
        green "  3. Change SSH Port"
        green "  4. Add SSH Key"
        green "  5. Install UFW"
        green "  6. Keep SSH Alive"
        green "  7. Optimize TCP"
        green "  8. Set Timezone"
        green "  9. Enable NTP Servers"
        green " 10. Set Journal Log Max Size"
        green " 11. Colorize Bash Prompt"
        green " 12. Install Nginx"
        yellow " *0. Exit"
        echo
        read -rp "Enter your menu choice [0-12]: " num
        echo
        case "$num" in
            1) install_common_packages ;; 
            2) change_hostname ;; 
            3) change_ssh_port ;; 
            4) add_ssh_key ;; 
            5) install_ufw ;; 
            6) keep_ssh_alive ;; 
            7) optimize_tcp ;; 
            8) set_timezone ;; 
            9) enable_ntp ;; 
            10) set_journal_log_size ;; 
            11) colorize_bash ;; 
            12) install_nginx ;; 
            0) echo "Bye ~ (^_^)v"; echo; exit 0 ;;
            *) red "Error: Invalid number." ;; 
        esac
    done
}

# Run
main
