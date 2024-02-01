# My Scripts

A collection of scripts I wrote for personal use, I'm not sure what these scripts do. #° 3°#

_Note: These scripts are intended for individual testing purposes in a controlled environment (most of them will only work on Debian). This means they may not be suitable for everyone. Please be sure you understand their functionality before running them._

## Table of contents

* [Server Startup](#server-startup)
* [Install Nginx](#install-nginx)
* [Issue SSL Cert](#acme-cert)

## Usage

### server-startup

An initialization script for efficiently managing newly deployed hosting servers. This script automates repetitive tasks that I need to perform each time I bring up a new one.

```
bash <(curl -Ls https://raw.githubusercontent.com/scenery/my-scripts/main/server-startup.sh)
```

- Change Hostname
- Change SSH Port
- Enable TCP BBR
- Install Nginx
- ...

### install-nginx

Auto compiling and installing the latest [Nginx](https://nginx.org). You can choose to install the stable version with the latest [OpenSSL](https://www.openssl.org/source/) or the mainline version with the latest [BoringSSL](https://boringssl.googlesource.com/boringssl) / [LibreSSL](https://www.libressl.org/).

```
bash <(curl -Ls git.io/nginx.sh)
```
or
```
bash <(curl -Ls https://raw.githubusercontent.com/scenery/my-scripts/main/install-nginx.sh)
```

### acme-cert

A tool designed for issuing SSL certificates using acme.sh with DNS API integration.

```
bash <(curl -Ls https://raw.githubusercontent.com/scenery/my-scripts/main/acme-cert.sh)
```

### ~~traceroute~~

_No longer maintained since May 9, 2022._

```
bash <(curl -Ls git.io/traceroute.sh)
```
or
```
bash <(curl -Ls https://raw.githubusercontent.com/scenery/my-scripts/main/traceroute.sh)
```

### ~~check-netflix~~

_No longer maintained since Feb 1, 2024._

```
bash <(curl -Ls https://raw.githubusercontent.com/scenery/my-scripts/main/check-netflix.sh)
```


