#!/bin/bash
# Written by ATP on 2023-12-06
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

ACME_SH_PATH="$HOME/.acme.sh"

issue_cert(){
    echo
    read -p "是否自定义 --config-home? (y/n，默认 [n]): " custom_config
    if [[ $custom_config =~ ^[Yy]$ ]]; then
        while true; do
            read -p "请输入自定义的 --config-home 路径 (绝对路径): " custom_path
            if [[ $custom_path != /* ]]; then
                red "路径必须是绝对路径，请重新输入。"
                continue
            fi
            if [ -d "$custom_path" ]; then
                acme_sh_home="$custom_path"
                break
            else
                read -p "路径不存在，是否创建? (y/n): " create_path
                if [[ $create_path =~ ^[Yy]$ ]]; then
                    mkdir -p "$custom_path"
                    echo "路径已创建: $custom_path"
                    acme_sh_home="$custom_path"
                    break
                else
                    yellow "请重新输入有效的绝对路径。"
                fi
            fi
        done
    else
        echo "使用默认路径。"
        acme_sh_home="$ACME_SH_PATH"
    fi
    green "您选择的 --config-home 路径为: $acme_sh_home"
    echo

    while true; do
        echo
        read -p "请输入证书安装路径 (绝对路径): " install_path
        if [[ $install_path != /* ]]; then
            red "路径必须是绝对路径，请重新输入。"
            continue
        fi
        if [ ! -d "$install_path" ]; then
            read -p "路径 $install_path 不存在，是否创建? (y/n): " create_path
            if [[ $create_path =~ ^[Yy]$ ]]; then
                mkdir -p "$install_path"
                echo "路径已创建。"
            else
                yellow "请重新输入证书安装路径。"
                continue
            fi
        fi
        break
    done

    while true; do
        echo "请选择证书颁发机构: "
        echo "1. Let's Encrypt"
        echo "2. ZeroSSL"
        echo "3. Google Trust Services"
        echo "4. 退出"
        read -p "输入相应的数字(1-4): " choice
        case $choice in
            1)
                cert_provider="letsencrypt"
                break
                ;;
            2)
                cert_provider="zerossl"
                break
                ;;
            3)
                cert_provider="google"
                break
                ;;
            4)
                echo "退出脚本。"
                exit 0
                ;;
            *)
                yellow "无效选择，请重新输入。"
                echo
                ;;
        esac
    done
    green "您选择的 CA 机构: $cert_provider"
    acme.sh --config-home $acme_sh_home --set-default-ca --server $cert_provider

    while true; do
        echo
        echo "请输入 DNS API 名称，对应你的 DNS 服务商，参考文档: https://github.com/acmesh-official/acme.sh/wiki/dnsapi"
        echo "例如文档中 1. Cloudflare 签发命令为: "
        echo -e "./acme.sh --issue --dns \033[32m\033[01mdns_cf\033[0m -d example.com -d '*.example.com'"
        echo "则对应的 DNS API 名称为: dns_cf"
        read -p "请输入: " dns_api_name
        echo "您输入的为: $dns_api_name"
        read -p "请再次确认，错误将会导致证书签发失败，是否正确? (y/n): " confirm
        if [[ $confirm =~ ^[Yy]$ ]]; then
            dns_name="$dns_api_name"
            break
        else
            continue
        fi
    done

    while true; do
        echo
        echo "请输入需要申请证书的域名，多个域名用空格隔开，例如: "
        echo "example.com *.example.com"
        read -p "输入域名: " domain_list
        # 将输入的域名列表转换为数组
        IFS=' ' read -ra domains <<< "$domain_list"
        cert_name="${domains[0]}"
        formatted_domains=""
        for domain in "${domains[@]}"; do
            formatted_domains+=" -d $domain"
        done
        echo "格式化后的域名列表:$formatted_domains"
        read -p "是否正确? (y/n): " confirm
        if [[ $confirm =~ ^[Yy]$ ]]; then
            echo
            echo "正在申请签发 RAS 证书..."
            acme.sh --config-home $acme_sh_home --issue --dns $dns_name $formatted_domains --keylength 2048
            acme.sh --config-home $acme_sh_home \
                --install-cert -d $cert_name \
                --key-file       $install_path/${cert_name}_private.key  \
                --fullchain-file $install_path/${cert_name}_fullchain.pem \
                --reloadcmd     "service nginx reload"
            green "RSA 证书已成功申请并安装。"
            echo
            read -p "是否继续安装 ECC 证书? (y/n): " confirm
            if [[ $confirm =~ ^[Yy]$ ]]; then
                acme.sh --config-home $acme_sh_home --issue --dns $dns_name $formatted_domains --keylength ec-256
                acme.sh --config-home $acme_sh_home \
                    --install-cert -d $cert_name --ecc \
                    --key-file       $install_path/ecc_${cert_name}_private.key  \
                    --fullchain-file $install_path/ecc_${cert_name}_fullchain.pem \
                    --reloadcmd     "service nginx reload"
                green "ECC 证书已成功申请并安装。"
                break
            else
                break
            fi
        else
            yellow "请重新输入域名列表。"
        fi
    done
}

main(){
    echo
    green "+--------------------------------------------------------+"
    green "| A tool to issue SSL certs using acme.sh with DNS API   |"
    green "| Written by ATP <https://atpx.com>                      |"
    green "| Github : https://github.com/scenery/my-scripts         |"
    green "+--------------------------------------------------------+"
    echo "在申请证书之前需要提前在 shell 中导入 DNS API Token，例如 (Cloudflare API): "
    echo "export CF_Token=\"xxxxxx\""
    echo "export CF_Account_ID=\"xxxxxx\""
    echo "export CF_Zone_ID=\"xxxxxx\""
    echo "DNS API 获取及使用方式请参考文档: https://github.com/acmesh-official/acme.sh/wiki/dnsapi"
    read -p "是否已经导入? (y/n): " answer
    if [ "$answer" == "y" ]; then
        if [ -d "$ACME_SH_PATH" ]; then
            green "acme.sh 已安装在 $ACME_SH_PATH"
            export PATH="$PATH:$HOME/.acme.sh"
        else
            yellow "未检测到 acme.sh 目录"
            echo "开始安装 acme.sh"
            echo
            curl https://get.acme.sh | sh
            source $HOME/.bashrc
            export PATH="$PATH:$HOME/.acme.sh"
            acme.sh --version
        fi
        issue_cert
        echo
        yellow "如果使用了自定义 --config-home，请在脚本退出后手动修改 crontab 任务指定 --config-home 路径，例如将默认任务: "
        echo '30 0 * * * "/root/.acme.sh"/acme.sh --cron --home "/root/.acme.sh" > /dev/null'
        echo "修改为: "
        echo '30 0 * * * "/root/.acme.sh"/acme.sh --cron --home "/root/.acme.sh" --config-home "/root/.custom_path" > /dev/null'
        yellow "如果未自定义 --config-home，忽略该消息即可。"
        echo
        green "本次签发证书完成。后续 acme.sh 将在后台定期自动更新证书，无需其它操作。"
        green "Bye~"
        sleep 1
        exit 0
    else
        yellow "脚本将自动退出，请手动导入 DNS API Token 后重新运行。"
        sleep 1
        exit 0
    fi
}

main
