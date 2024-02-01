#!/bin/bash
# Github: https://github.com/scenery/my-scripts
# Last updated on: 2023-02-01
# Note: This script is no longer maintained

red(){
    echo -e "\033[31m\033[01m$1\033[0m"
}
green(){
    echo -e "\033[32m\033[01m$1\033[0m"
}
yellow(){
    echo -e "\033[33m\033[01m$1\033[0m"
}
blue(){
    echo -e "\033[34m\033[01m$1\033[0m"
}

function unlock_test() {
    local region_test="https://www.netflix.com/title/80018499"
    local self_produced_test="https://www.netflix.com/title/81280792"
    local licensed_test="https://www.netflix.com/title/70143836"

    local region=$(curl -${1} --user-agent "${UA}" -fs --max-time 5 --write-out %{redirect_url} --output /dev/null ${region_test} 2>&1 | cut -d '/' -f4 | cut -d '-' -f1 | tr [:lower:] [:upper:])
    if [[ ! -n "$region" ]]; then
        region="US"
    fi
    sleep 1
    local self_result=$(curl -${1} --user-agent "${UA}" -fsL --write-out %{http_code} --output /dev/null --max-time 5 ${self_produced_test} 2>&1)
    sleep 1
    local licensed_result=$(curl -${1} --user-agent "${UA}" -fsL --write-out %{http_code} --output /dev/null --max-time 5 ${licensed_test} 2>&1)
    
    if [[ "${self_result}" == "403" ]] && [[ "${licensed_result}" == "403" ]]; then
        yellow "Your IPv${1} address can unblock Netflix (region: $region) but only Netflix original content.";
        return
    elif [[ "${self_result}" == "404" ]] && [[ "${licensed_result}" == "404" ]]; then
        yellow "Your IPv${1} address can unblock Netflix (region: $region) but only Netflix original content.";
        return
        red "Sorry, Your IPv${1} address is blocked by Netflix.";
        return
    elif [[ "${self_result}" == "200" ]] && [[ "${licensed_result}" == "200" ]]; then
        green "Congrats! Your IPv${1} address can unblock all Netflix (region: $region) content.";
        return
    else
        yellow "Network error, please try again later."
        return
    fi
}

main() {
    UA="Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.3 Safari/605.1.15"
    echo "--------------------------------------------------"
    echo "A script to test whether your network can unlock "
    echo "Netflix streaming playback."
    echo
    echo "** Note: This script is no longer maintained since"
    echo "Feb 2024, and the results may not be accurate."
    echo "--------------------------------------------------"
    echo
    echo "## Testing IPv4 ..."
    local check4=`ping 1.1.1.1 -c 1 2>&1 | grep -i "unreachable"`;
    if [ "$check4" == "" ];then
        unlock_test "4"
    else
        blue "This host does not support IPv4 address, skipping...";
    fi
    echo "## Testing IPv6 ... "
    local check6=`ping6 2606:4700:4700::1111 -c 1 2>&1 | grep -i "unreachable"`;
    if [ "$check6" == "" ];then
        unlock_test "6"
    else
        blue "This host does not support IPv6 address, skipping...";
    fi
    echo
}

main
