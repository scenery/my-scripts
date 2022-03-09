#!/bin/bash
# Check if your IPs unblock Netflix streaming
# Website: https://www.zatp.com
# Github: https://github.com/scenery/my-scripts
function test_ipv4() {
    result=`curl -4sSL "https://www.netflix.com/" | grep "Not Available"`;
    if [ "$result" != "" ];then
        echo -e "\033[34m很遗憾 Netflix 不服务此地区\033[0m";
        return;
    fi
    
    result=`curl -4sSL "https://www.netflix.com/title/80018499" | grep "page-404"`;
    if [ "$result" != "" ];then
        echo -e "\033[34m很遗憾 你的 IPv4 不能看 Netflix\033[0m";
        return;
    fi
    
    result1=`curl -4sSL "https://www.netflix.com/title/70143836" | grep "page-404"`;
    result2=`curl -4sSL "https://www.netflix.com/title/80027042" | grep "page-404"`;
    result3=`curl -4sSL "https://www.netflix.com/title/70140425" | grep "page-404"`;
    result4=`curl -4sSL "https://www.netflix.com/title/70283261" | grep "page-404"`;
    result5=`curl -4sSL "https://www.netflix.com/title/70143860" | grep "page-404"`;
    result6=`curl -4sSL "https://www.netflix.com/title/70202589" | grep "page-404"`;
    
    if [[ "$result1" != "" ]] && [[ "$result2" != "" ]] && [[ "$result3" != "" ]] && [[ "$result4" != "" ]] && [[ "$result5" != "" ]] && [[ "$result6" != "" ]];then
        echo -e "\033[33m你的 IPv4 可以打开 Netflix 但是仅解锁自制剧\033[0m";
        return;
    fi
    
    echo -e "\033[32m恭喜 你的 IPv4 可以打开 Netflix 并解锁全部流媒体\033[0m";
    return;
}

function test_ipv6() {
    result=`curl -6sSL "https://www.netflix.com/" | grep "Not Available"`;
    if [ "$result" != "" ];then
        echo -e "\033[34m很遗憾 Netflix 不服务此地区\033[0m";
        return;
    fi
    
    result=`curl -6sSL "https://www.netflix.com/title/80018499" | grep "page-404"`;
    if [ "$result" != "" ];then
        echo -e "\033[34m很遗憾 你的 IPv6 不能看 Netflix\033[0m";
        return;
    fi
    
    result1=`curl -6sSL "https://www.netflix.com/title/70143836" | grep "page-404"`;
    result2=`curl -6sSL "https://www.netflix.com/title/80027042" | grep "page-404"`;
    result3=`curl -6sSL "https://www.netflix.com/title/70140425" | grep "page-404"`;
    result4=`curl -6sSL "https://www.netflix.com/title/70283261" | grep "page-404"`;
    result5=`curl -6sSL "https://www.netflix.com/title/70143860" | grep "page-404"`;
    result6=`curl -6sSL "https://www.netflix.com/title/70202589" | grep "page-404"`;
    
    if [[ "$result1" != "" ]] && [[ "$result2" != "" ]] && [[ "$result3" != "" ]] && [[ "$result4" != "" ]] && [[ "$result5" != "" ]] && [[ "$result6" != "" ]];then
        echo -e "\033[33m你的 IPv6 可以打开 Netflix 但是仅解锁自制剧\033[0m";
        return;
    fi
    
    echo -e "\033[32m恭喜 你的 IPv6 可以打开 Netflix 并解锁全部流媒体\033[0m";
    return;
}

echo " ** 正在测试 IPv4 解锁情况";
check4=`ping 1.1.1.1 -c 1 2>&1 | grep -i "unreachable"`;
if [ "$check4" == "" ];then
    test_ipv4;
else
    echo -e "\033[34m当前主机不支持 IPv4,跳过...\033[0m";
fi
echo " ** 正在测试 IPv6 解锁情况";
check6=`ping6 240c::6666 -c 1 2>&1 | grep -i "unreachable"`;
if [ "$check6" == "" ];then
    test_ipv6;
else
    echo -e "\033[34m当前主机不支持 IPv6,跳过...\033[0m";
fi
