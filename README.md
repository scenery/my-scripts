# My Scripts

Some useful scripts written by myself, but I have no idea what they are :-)

_Notice: All scripts are use for personal test in single environment (most of them will only run on Debian GNU/Linux) that means it may not be suitable for all people. You must know what you're doing before run them._

## Table of contents

* [Server Startup](#server-startup)
* [Install Nginx](#install-nginx)
* [Traceroute](#traceroute)
* [Unblock Netflix Check](#check-netflix)
* [Issue SSL Cert](#acme-cert)

## Usage

### server-startup

An initialization script for managing newly deployed cloud servers. This script can help me to automate the tasks I have to set up again and again when booting up a new host.

```
bash <(curl -Ls https://raw.githubusercontent.com/scenery/my-scripts/main/server-startup.sh)
```

- Change Hostname
- Change SSH Port
- Enable TCP BBR
- Install Nginx
- ...

### install-nginx

Auto compiling and installing the latest [Nginx](https://nginx.org/en/download.html) with [OpenSSL](https://www.openssl.org/source/) or [LibreSSL](https://www.libressl.org/).
```
bash <(curl -Ls git.io/nginx.sh)
```
or
```
bash <(curl -Ls https://raw.githubusercontent.com/scenery/my-scripts/main/install-nginx.sh)
```

### traceroute

A simple tool to test traceroute from your VPS/Server to Mainland China, powered by Besttrace (ipip.net).
```
bash <(curl -Ls git.io/traceroute.sh)
```
or
```
bash <(curl -Ls https://raw.githubusercontent.com/scenery/my-scripts/main/traceroute.sh)
```

### check-netflix

A easy and fast script to check if your IPv4 and IPv6 address can unblock Netflix streaming.
```
bash <(curl -Ls https://raw.githubusercontent.com/scenery/my-scripts/main/check-netflix.sh)
```

### acme-cert

A tool to issue SSL certs using acme.sh with DNS API.
```
bash <(curl -Ls https://raw.githubusercontent.com/scenery/my-scripts/main/acme-cert.sh)
```

