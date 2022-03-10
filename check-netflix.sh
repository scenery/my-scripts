#!/bin/bash
# Check if your IPs unblock Netflix streaming
# Website: https://www.zatp.com
# Github: https://github.com/scenery/my-scripts

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

test_ipv4() {
    result=`curl -4sSL "https://www.netflix.com/" | grep "Not Available"`;
    if [ "$result" != "" ];then
        blue "Sorry, Netflix is not available based on your IPv4 address region.";
        return;
    fi
    
    result=`curl -4sSL "https://www.netflix.com/title/80018499" | grep "page-404"`;
    if [ "$result" != "" ];then
        red "Sorry, Your IPv4 address is blocked by Netflix.";
        return;
    fi

    region=`tr [:lower:] [:upper:] <<< $(curl -4is "https://www.netflix.com/title/80018499" 2>&1 | sed -n '8p' | awk '{print $2}' | cut -d '/' -f4 | cut -d '-' -f1)` ;

    if [[ "$region" == *"INDEX"* ]];then
       region="US";
    fi
    
    result1=`curl -4sSL "https://www.netflix.com/title/70143836" | grep "page-404"`;
    result2=`curl -4sSL "https://www.netflix.com/title/80027042" | grep "page-404"`;
    result3=`curl -4sSL "https://www.netflix.com/title/70140425" | grep "page-404"`;
    result4=`curl -4sSL "https://www.netflix.com/title/70283261" | grep "page-404"`;
    result5=`curl -4sSL "https://www.netflix.com/title/70143860" | grep "page-404"`;
    result6=`curl -4sSL "https://www.netflix.com/title/70202589" | grep "page-404"`;
    
    if [[ "$result1" != "" ]] && [[ "$result2" != "" ]] && [[ "$result3" != "" ]] && [[ "$result4" != "" ]] && [[ "$result5" != "" ]] && [[ "$result6" != "" ]];then
        yellow "Your IPv4 address can unblock Netflix (region: $region) but only Netflix original content.";
        return;
    fi
    
    green "Congrats! Your IPv4 address can unblock all Netflix (region: $region) content.";
    return;
}

test_ipv6() {
    result=`curl -6sSL "https://www.netflix.com/" | grep "Not Available"`;
    if [ "$result" != "" ];then
        blue "Sorry, Netflix is not available based on your IPv6 address region.";
        return;
    fi
    
    result=`curl -6sSL "https://www.netflix.com/title/80018499" | grep "page-404"`;
    if [ "$result" != "" ];then
        red "Sorry, Your IPv6 address is blocked by Netflix.";
        return;
    fi

    region=`tr [:lower:] [:upper:] <<< $(curl -6is "https://www.netflix.com/title/80018499" 2>&1 | sed -n '8p' | awk '{print $2}' | cut -d '/' -f4 | cut -d '-' -f1)` ;
    
    if [[ "$region" == *"INDEX"* ]];then
       region="US";
    fi
    
    result1=`curl -6sSL "https://www.netflix.com/title/70143836" | grep "page-404"`;
    result2=`curl -6sSL "https://www.netflix.com/title/80027042" | grep "page-404"`;
    result3=`curl -6sSL "https://www.netflix.com/title/70140425" | grep "page-404"`;
    result4=`curl -6sSL "https://www.netflix.com/title/70283261" | grep "page-404"`;
    result5=`curl -6sSL "https://www.netflix.com/title/70143860" | grep "page-404"`;
    result6=`curl -6sSL "https://www.netflix.com/title/70202589" | grep "page-404"`;
    
    if [[ "$result1" != "" ]] && [[ "$result2" != "" ]] && [[ "$result3" != "" ]] && [[ "$result4" != "" ]] && [[ "$result5" != "" ]] && [[ "$result6" != "" ]];then
        yellow "Your IPv6 address can unblock Netflix (region: $region) but only Netflix original content.";
        return;
    fi
    
    green "Congrats! Your IPv6 address can unblock all Netflix (region: $region) content.";
    return;
}

main() {
    echo "=================================================="
    echo "Testing IPv4 ... "
    check4=`ping 1.1.1.1 -c 1 2>&1 | grep -i "unreachable"`;
    if [ "$check4" == "" ];then
        test_ipv4;
    else
        blue "This host does not support IPv4 address, skipping...";
    fi
    echo "--------------------------------------------------"
    echo "Testing IPv6 ... "
    check6=`ping6 240c::6666 -c 1 2>&1 | grep -i "unreachable"`;
    if [ "$check6" == "" ];then
        test_ipv6;
    else
        blue "This host does not support IPv6 address, skipping...";
    fi
    echo "=================================================="
}

main
