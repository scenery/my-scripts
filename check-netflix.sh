#!/bin/bash
# Check if your IPs unblock Netflix streaming
# Website: https://www.zatp.com
# Github: https://github.com/scenery/my-scripts

function test_ipv4() {
    result=`curl -4sSL "https://www.netflix.com/" | grep "Not Available"`;
    if [ "$result" != "" ];then
        echo -e "\033[34mSorry, Netflix is not available in your IPv4's region.\033[0m";
        return;
    fi
    
    result=`curl -4sSL "https://www.netflix.com/title/80018499" | grep "page-404"`;
    if [ "$result" != "" ];then
        echo -e "\033[34mSorry, Your IPv4 is blocked by Netflix.\033[0m";
        return;
    fi
    
    result1=`curl -4sSL "https://www.netflix.com/title/70143836" | grep "page-404"`;
    result2=`curl -4sSL "https://www.netflix.com/title/80027042" | grep "page-404"`;
    result3=`curl -4sSL "https://www.netflix.com/title/70140425" | grep "page-404"`;
    result4=`curl -4sSL "https://www.netflix.com/title/70283261" | grep "page-404"`;
    result5=`curl -4sSL "https://www.netflix.com/title/70143860" | grep "page-404"`;
    result6=`curl -4sSL "https://www.netflix.com/title/70202589" | grep "page-404"`;
    
    if [[ "$result1" != "" ]] && [[ "$result2" != "" ]] && [[ "$result3" != "" ]] && [[ "$result4" != "" ]] && [[ "$result5" != "" ]] && [[ "$result6" != "" ]];then
        echo -e "\033[33mYour IPv4 can unblock Netflix but only Netflix original content.\033[0m";
        return;
    fi
    
    echo -e "\033[32mCongrats! Your IPv4 can unblock all Netflix content.\033[0m";
    return;
}

function test_ipv6() {
    result=`curl -6sSL "https://www.netflix.com/" | grep "Not Available"`;
    if [ "$result" != "" ];then
        echo -e "\033[34mSorry, Netflix is not available in your IPv6's region.\033[0m";
        return;
    fi
    
    result=`curl -6sSL "https://www.netflix.com/title/80018499" | grep "page-404"`;
    if [ "$result" != "" ];then
        echo -e "\033[34mSorry, Your IPv6 is blocked by Netflix.\033[0m";
        return;
    fi
    
    result1=`curl -6sSL "https://www.netflix.com/title/70143836" | grep "page-404"`;
    result2=`curl -6sSL "https://www.netflix.com/title/80027042" | grep "page-404"`;
    result3=`curl -6sSL "https://www.netflix.com/title/70140425" | grep "page-404"`;
    result4=`curl -6sSL "https://www.netflix.com/title/70283261" | grep "page-404"`;
    result5=`curl -6sSL "https://www.netflix.com/title/70143860" | grep "page-404"`;
    result6=`curl -6sSL "https://www.netflix.com/title/70202589" | grep "page-404"`;
    
    if [[ "$result1" != "" ]] && [[ "$result2" != "" ]] && [[ "$result3" != "" ]] && [[ "$result4" != "" ]] && [[ "$result5" != "" ]] && [[ "$result6" != "" ]];then
        echo -e "\033[33mYour IPv6 can unblock Netflix but only Netflix original content.\033[0m";
        return;
    fi
    
    echo -e "\033[32mCongrats! Your IPv6 can unblock all Netflix content.\033[0m";
    return;
}

echo -e "\033[47;30mTesting IPv4 ../\033[0m"
check4=`ping 1.1.1.1 -c 1 2>&1 | grep -i "unreachable"`;
if [ "$check4" == "" ];then
    test_ipv4;
else
    echo -e "\033[34mThe host does not support IPv4 address, skip...\033[0m";
fi
echo -e "\033[47;30mTesting IPv6 ../\033[0m"
check6=`ping6 240c::6666 -c 1 2>&1 | grep -i "unreachable"`;
if [ "$check6" == "" ];then
    test_ipv6;
else
    echo -e "\033[34mThe host does not support IPv6 address, skip...\033[0m";
fi
