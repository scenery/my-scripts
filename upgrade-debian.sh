#!/bin/bash
# Written by ATP on 2026-12-25
# Website: https://atpx.com
# Github: https://github.com/scenery/my-scripts

green(){ echo -e "\033[32m\033[01m${1}\033[0m"; }
red(){ echo -e "\033[31m\033[01m${1}\033[0m"; }
yellow(){ echo -e "\033[33m\033[01m${1}\033[0m"; }

confirm() {
    local prompt="${1:-Are you sure? (y/n, default y): }"
    local response
    while true; do
        read -r -p "${prompt}" response
        response=${response:-y}
        case "${response}" in
            [Yy][Ee][Ss]|[Yy]) return 0 ;;
            [Nn][Oo]|[Nn]) return 1 ;;
            *) red "Invalid option. Please enter yes or no." ;;
        esac
    done
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        red "Error: This script must be run as root. Please run with sudo or as root."
        exit 1
    fi
}

check_system() {
    if [ ! -f /etc/debian_version ]; then
        red "Error: This script is designed for Debian systems only."
        exit 1
    fi
}

get_local_system_info() {
    CURRENT_CODENAME=$(grep -oP 'VERSION_CODENAME=\K\w+' /etc/os-release 2>/dev/null)
    if [ -z "$CURRENT_CODENAME" ]; then
        CURRENT_CODENAME=$(lsb_release -cs 2>/dev/null || echo "unknown")
    fi
    CURRENT_VERSION=$(cat /etc/debian_version 2>/dev/null || echo "unknown")

    # Map next consecutive version sequence (Debian forbids skipping releases)
    case "${CURRENT_CODENAME}" in
        buster)
            NEXT_CODENAME="bullseye"
            NEXT_VERSION_NUM="11"
            ;;
        bullseye)
            NEXT_CODENAME="bookworm"
            NEXT_VERSION_NUM="12"
            ;;
        bookworm)
            NEXT_CODENAME="trixie"
            NEXT_VERSION_NUM="13"
            ;;
        trixie)
            NEXT_CODENAME="forky"
            NEXT_VERSION_NUM="14"
            ;;
        forky)
            NEXT_CODENAME="duke"
            NEXT_VERSION_NUM="15"
            ;;
        *)
            NEXT_CODENAME=""
            NEXT_VERSION_NUM=""
            ;;
    esac
}

fetch_official_latest_stable() {
    if [ -n "$OFFICIAL_STABLE_FETCHED" ]; then
        return
    fi

    local release_url="http://deb.debian.org/debian/dists/stable/Release"
    local release_content=""

    if command -v curl &>/dev/null; then
        release_content=$(curl -sL --connect-timeout 6 --max-time 10 "${release_url}" | head -n 30)
    elif command -v wget &>/dev/null; then
        release_content=$(wget -qO- --timeout=6 "${release_url}" | head -n 30)
    fi

    if [ -n "$release_content" ]; then
        OFFICIAL_STABLE_CODENAME=$(echo "$release_content" | grep -m1 '^Codename:' | awk '{print $2}')
        OFFICIAL_STABLE_VERSION=$(echo "$release_content" | grep -m1 '^Version:' | awk '{print $2}')
    fi

    if [ -n "$OFFICIAL_STABLE_CODENAME" ] && [ -n "$OFFICIAL_STABLE_VERSION" ]; then
        OFFICIAL_STABLE_FETCHED=1
    else
        red "Error: Network error. Failed to fetch official stable release from deb.debian.org. Please try again later."
        exit 1
    fi
}

check_updates() {
    yellow "Checking for available package updates..."
    apt update -qq
    UPGRADABLE_COUNT=$(apt --just-print dist-upgrade 2>/dev/null | grep -Po '^\d+(?= upgraded)' || echo "0")
    if [ "$UPGRADABLE_COUNT" -gt 0 ]; then
        green "Found ${UPGRADABLE_COUNT} package(s) can be upgraded."
        return 0
    else
        yellow "No package updates available for current release (${CURRENT_CODENAME} - ${CURRENT_VERSION})."
        return 1
    fi
}

cleanup_and_reboot() {
    echo ""
    if confirm "$(yellow "Do you want to clean up unused packages (apt autoremove & autoclean)? (y/n, default y): ")"; then
        yellow "Cleaning up unused packages..."
        export DEBIAN_FRONTEND=noninteractive
        apt --purge autoremove -y
        apt autoclean -y
        green "Package cleanup completed."
    else
        yellow "Cleanup skipped."
    fi

    echo ""
    if confirm "$(yellow "A system reboot is strongly recommended. Reboot now? (y/n, default y): ")"; then
        green "System is rebooting now..."
        sleep 2
        reboot
    else
        yellow "Reboot skipped. Please remember to reboot manually later."
    fi
}

update_current_system() {
    if ! check_updates; then
        return
    fi

    if ! confirm "$(yellow "Do you want to apply these updates now? (y/n, default y): ")"; then
        yellow "Update canceled."
        return
    fi

    green "Starting update for Debian (${CURRENT_CODENAME} - ${CURRENT_VERSION})..."
    export DEBIAN_FRONTEND=noninteractive

    yellow "Applying upgrades..."
    apt upgrade -y
    apt dist-upgrade -y

    green "System update completed."
    cleanup_and_reboot
}

upgrade_major_version() {
    local current_major="${CURRENT_VERSION_ID:-${CURRENT_VERSION%%.*}}"

    if [ "$CURRENT_CODENAME" == "$OFFICIAL_STABLE_CODENAME" ]; then
        yellow "Notice: Your system (Debian ${current_major} ${CURRENT_CODENAME}) is already running the official latest stable release."
        if ! confirm "$(yellow "Do you still want to re-run the full-upgrade process? (y/n, default n): ")"; then
            return
        fi
        TARGET_CODENAME="${CURRENT_CODENAME}"
        TARGET_VERSION_NUM="${OFFICIAL_STABLE_VERSION}"
    else
        if [ -z "$NEXT_CODENAME" ]; then
            red "Error: Cannot identify the next sequential Debian release after '${CURRENT_CODENAME}'."
            return
        fi

        TARGET_CODENAME="${NEXT_CODENAME}"
        TARGET_VERSION_NUM="${NEXT_VERSION_NUM}"

        yellow "WARNING: You are about to upgrade from Debian ${current_major} (${CURRENT_CODENAME}) to Debian ${TARGET_VERSION_NUM} (${TARGET_CODENAME})."
        if ! confirm "$(yellow "Are you sure you want to proceed with the major upgrade? (y/n, default y): ")"; then
            yellow "Upgrade canceled."
            return
        fi

        # Replace current codename with target codename in existing apt sources
        yellow "Replacing '${CURRENT_CODENAME}' with '${TARGET_CODENAME}' in APT sources..."
        if [ -f /etc/apt/sources.list ]; then
            sed -i "s/${CURRENT_CODENAME}/${TARGET_CODENAME}/g" /etc/apt/sources.list
        fi

        if [ -d /etc/apt/sources.list.d ]; then
            find /etc/apt/sources.list.d/ -type f \( -name "*.list" -o -name "*.sources" \) -exec sed -i "s/${CURRENT_CODENAME}/${TARGET_CODENAME}/g" {} +
        fi
    fi

    export DEBIAN_FRONTEND=noninteractive

    yellow "Updating package lists for Debian ${TARGET_VERSION_NUM} (${TARGET_CODENAME})..."
    apt update

    yellow "Phase 1: Performing minimal upgrade (without new packages)..."
    apt upgrade --without-new-pkgs -y

    yellow "Phase 2: Performing full distribution upgrade..."
    apt full-upgrade -y

    green "Upgrade to Debian ${TARGET_VERSION_NUM} (${TARGET_CODENAME}) completed successfully!"
    cleanup_and_reboot
}

menu() {
    fetch_official_latest_stable

    while true; do
        get_local_system_info
        echo ""
        green "=========================================================="
        green "          Debian System Upgrade & Maintenance Tool        "
        green "=========================================================="
        echo -e " Current Codename : $(green "${CURRENT_CODENAME}")"
        echo -e " Current Version  : $(green "${CURRENT_VERSION}")"
        if [ -n "$OFFICIAL_STABLE_CODENAME" ]; then
            echo -e " Official Stable  : $(green "Debian ${OFFICIAL_STABLE_VERSION} (${OFFICIAL_STABLE_CODENAME})")"
        fi
        green "----------------------------------------------------------"
        echo "  1. Update current system to latest (${CURRENT_CODENAME} point release)"

        if [ "$CURRENT_CODENAME" == "$OFFICIAL_STABLE_CODENAME" ]; then
            echo -e "  2. System is already at latest stable ($(green "${CURRENT_CODENAME}")) [Re-verify]"
        elif [ -n "$NEXT_CODENAME" ]; then
            echo "  2. Upgrade to Debian ${NEXT_VERSION_NUM} (${NEXT_CODENAME})"
        else
            echo "  2. Upgrade to next major release (Unsupported codename)"
        fi

        echo "  0. Exit"
        echo

        while true; do
            read -r -p "Please enter your choice [0-2]: " choice
            case "${choice}" in
                1)
                    update_current_system
                    break
                    ;;
                2)
                    upgrade_major_version
                    break
                    ;;
                0)
                    echo "Bye ~ (^_^)v"
		    echo
                    exit 0
                    ;;
                *)
                    red "Invalid input: '${choice}'. Please enter a valid option (0, 1, or 2)."
                    ;;
            esac
        done
    done
}

check_root
check_system
menu
