# MyScripts

Some useful scripts written by myself, but I have no idea what they are :-)

## Table of contents

* [Install Nginx](#install-nginx)
* [Install Linux OS](#install-linux)


## Usage

_Notice: All scripts are use for personal test in single environment, it may not apply to everyone._

### install-nginx

Auto compiling and installing Nginx-v1.20.1
```
bash <(curl -Ls git.io/nginx.sh)
```

### install-linux

Auto install Linux OS (Debian, Ubuntu, CentOS) with DD if your VPS do not support VNC function, this is a backup file of moeclub.org.

Default User: root; Password: MoeClub.org

```
bash <(curl -Ls https://raw.githubusercontent.com/scenery/MyScripts/main/InstallNET.sh) -[command]
```

Command:
```
-d [dists-name]
-u [dists-name]
-c [dists-verison]
-v [32/i386|64/amd64]
-p [password]
--ip-addr [ip-address]
--ip-gate [gateway]
--ip-mask [netmask]
--mirror [mirror link]
-dd [install image with dd function]
-a [auto install]
-m [manual insall]
```

**e.g.**

\*Only suppopt 6.10 or lower version for CentOS

\# Auto install Debian 11 (bullseye) with custom password:
```
bash <(curl -Ls git.io/ddlinux.sh) -d 11 -v 64 -p password -a
```

\# Auto install Debian 11 with custom mirror:
```
bash <(curl -Ls git.io/ddlinux.sh) -d 11 -v 64 -a --mirror 'http://mirrors.ustc.edu.cn/debian/'
```

\# Auto install Ubuntu 20.04 with custom network config if your VPS do not support DHCP:
```
bash <(curl -Ls git.io/ddlinux.sh) -u 20.04 -v 64 -a --ip-addr x.x.x.x --ip-gate x.x.x.x --ip-mask x.x.x.x
```

* --ip-addr : IP Address
* --ip-gate : Gateway
* --ip-mask : Netmask

