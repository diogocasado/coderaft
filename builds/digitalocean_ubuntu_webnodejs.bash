#!/bin/bash
# MIT License
# 
# Copyright (c) 2022 Diogo Casado
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
# set -x
CODERAFT=1
VERBOSE=0
PROMPT=1
CONFIRM_PROMPT=()
if [ $EUID != 0 ]; then
	echo "Requires root. Sorry."
	exit 1
fi
if [ ! -z "$(command -v tput)" ]; then
	NCOLORS=$(tput colors)
	if [ $NCOLORS -ge 8 ]; then
		BOLD="$(tput bold)"
		UNDERLINE="$(tput smul)"
		STANDOUT="$(tput smso)"
		NORMAL="$(tput sgr0)"
		BLACK="$(tput setaf 0)"
		RED="$(tput setaf 1)"
		GREEN="$(tput setaf 2)"
		YELLOW="$(tput setaf 3)"
		BLUE="$(tput setaf 4)"
		MAGENTA="$(tput setaf 5)"
		CYAN="$(tput setaf 6)"
		WHITE="$(tput setaf 7)"
		_BLACK="$(tput setab 0)"
		_RED="$(tput setab 1)"
		_GREEN="$(tput setab 2)"
		_YELLOW="$(tput setab 3)"
		_BLUE="$(tput setab 4)"
		_MAGENTA="$(tput setab 5)"
		_CYAN="$(tput setab 6)"
		_WHITE="$(tput setab 7)"
	fi
fi
log_debug () {
	if [ $VERBOSE -gt 0 ]; then
		echo "${CYAN}(Debug) $@ ${NORMAL}"
	fi
}
log_debug_file () {
	if [ $VERBOSE -gt 0 ]; then
		echo "${CYAN}(Debug) Listing file $1 ${MAGENTA}"
		cat $1
		echo "${NORMAL}"
	fi
}
log_warn () {
	echo "${YELLOW}(Warning) $@ ${NORMAL}"
}
log_error () {
	echo "${RED}(Error) $@ ${NORMAL}"
	exit 1
}
prompt_input () {
	local DESC=$1
	local VARNAME=$2
	local DEFVALUE=$3
	CONFIRM_PROMPT+=("$VARNAME:${DESC% (*}")
	if [ $PROMPT -gt 0 ]; then
		echo -n "${BLUE}${_WHITE}"
		local -n VAR="$VARNAME"
		while [ -z "$VAR" ]; do
			read -r -p "$DESC: " $VARNAME
			if [ -z "$VAR" ] && [ ! -z "$DEFVALUE" ]; then
				if [ "${DEFVALUE^^}" == "NULL" ]; then
					break
				fi
				VAR="$DEFVALUE"
			fi
		done
		echo -n "${NORMAL}"
		echo -ne "\e[2K"
	fi
}
prompt_input_yn () {
	local DESC=$1
	local VARNAME=$2
	local DEFVALUE=${3^^}
	CONFIRM_PROMPT+=("$VARNAME:${DESC% (*}")
	if [ $PROMPT -gt 0 ]; then
		echo -n "${BLUE}${_WHITE}${DESC} "
		if [ "$DEFVALUE" == "Y" ]; then
			echo -n "[Y/n]: "
		elif [ "$DEFVALUE" == "N" ]; then
			echo -n "[y/N]: "
		else
			echo -n "[y/n]: "
		fi
		local -n VAR="$VARNAME"
		while [ -z "$VAR" ]; do
			read -rs -N 1
			if [ "$REPLY" == $'\n' ]; then
				REPLY="$DEFVALUE"
			fi
			local CHOICE="${REPLY^^}"
			if [ "$CHOICE" == "N" ]; then
				echo "No"
				VAR=0
			elif [ "$CHOICE" == "Y" ]; then
				echo "Yes"
				VAR=1
			fi
		done
		echo -n "${NORMAL}"
		echo -ne "\e[2K"
	fi
}
print_raft () {
	cat <<-EOF 
	       I\\
	       I \\
	       I  \\
	       I*--\\
	       I  x \\
	       I 404 \\
	       I______\\
	 ______I_________
	 \\  \\        \\  \\  ^  ^
	 ^^^^^^^^^^^^^^^^^    ^
	EOF
}
print_greet () {
	echo -n "${BLUE}"
	echo "Coderaft - VPS server configurator"
	echo "https://github.com/diogocasado/coderaft"
	echo -n "${NORMAL}"
}
invoke_func () {
	local FUNC=${1//-/_}
	local INFO=$2
	if [ ! -z "$(type -t $FUNC)" ]; then
		[ ! -z "$INFO" ] && echo "${BLUE}$INFO${NORMAL}"
		log_debug "Invoke $FUNC"
		"$FUNC"
	fi
}
floatme () {
	print_raft
	print_greet
	CPUS=$(lscpu | awk '/^CPU\(s\):/ { print $2 }')
	MEM=$(free | awk '/^Mem:/ { printf "%.0f%c", ($2>900000 ? $2/1000000 : $2/1000), ($2>900000 ? "G" : "M") }')
	invoke_func "platform_init"
	invoke_func "dist_init"
	invoke_func "raft_init"
	echo "Platform: $PLAT_DESC"
	echo "Size: $CPUS vCPU, $MEM"
	echo "Distribution: $DIST_NAME $DIST_VER"
	echo "Raft: $RAFT_ID"
	echo "Packages: $PKGS"
	invoke_func "platform_setup"
	invoke_func "dist_setup"
	invoke_func "raft_setup"
	for PKG in $PKGS; do
		invoke_func "${PKG,,}_setup"
		invoke_func "${PKG,,}_setup_${DIST_ID}"
	done
	log_debug "Prompts are ${CONFIRM_PROMPT[@]}"
	echo "Please review:${GREEN}"
	for PAIR in "${CONFIRM_PROMPT[@]}"; do
		DESC="${PAIR#*:}"
		VAR="${PAIR%:*}"
		echo "$DESC: ${!VAR}"
	done
	echo -n "${NORMAL}"
	prompt_input_yn "Continue?" CONFIRM
	[ $CONFIRM -eq 0 ] && exit 1
	invoke_func "dist_prepare"
	for PKG in $PKGS; do
		echo "${BLUE}== Install $PKG ${NORMAL}"
		invoke_func "${PKG,,}_install"
		invoke_func "${PKG,,}_install_${DIST_ID}"
	done
	for PKG in $PKGS; do
		invoke_func "${PKG,,}_finish" \
			"== Wrapping up ${PKG}"
	done
	echo "${BLUE}== Cleaning up${NORMAL}"
	invoke_func "platform_finish"
	invoke_func "dist_finish"
	invoke_func "raft_finish"
	echo "Done."
}
# ubuntu.bash f541fc37 
DIST_ID=ubuntu
DIST_NAME=Ubuntu
DIST_DESC="Ubuntu is the modern, open source operating system on Linux for the enterprise server, desktop, cloud, and IoT."
dist_init () {
	DIST_CODENAME=$(lsb_release -c | awk '{ print $2 }')
	DIST_VER=$(lsb_release -r | awk '{ print $2 }')
	DIST_VER_MAJOR=$(echo $DIST_VER | awk 'match($0, /([0-9]*)\./, m) { print m[1] }')
	DIST_VER_MINOR=$(echo $DIST_VER | awk 'match($0, /[0-9]*\.([0-9]*)/, m) { print m[1] }')
	APT_SOURCES_DIR=/etc/apt/sources.list.d
	KEYRING_DIR="/usr/share/keyrings"
}
dist_prepare () {
	echo "Updating packages..."
	export DEBIAN_FRONTEND=noninteractive
	apt-get update
	apt-get upgrade -y
}
dist_finish () {
	echo "Cleaning up..."
	apt-get autoremove -y
	apt-get autoclean
	echo "${BOLD}Please reboot.${NORMAL}"
}
# digitalocean.bash 305013d6 
PLAT_ID=do
PLAT_DESC="DigitalOcean (https://digitalocean.com)"
VLAN_IFACE="eth0"
VLAN_SUBNET="10.132.0.0/16"
platform_setup () {
	prompt_input "DigitalOcean Token" DO_TOKEN null
}
# webnodejs.bash af0234a7 
RAFT_ID=webnodejs
RAFT_DESC="A simple Node.js + MongoDB raft."
PKGS="nftables nginx letsencrypt nodejs mongodb git git-clone paddle"
# nftables.bash 9f606cfd 
FIREWALL=nftables
nftables_setup () {
	prompt_input "VLAN ifname" VLAN_IFACE
	prompt_input "VLAN subnet" VLAN_SUBNET
	if [ -z $(command -v nft) ]; then
		echo "(Error) Command nft not found"
		exit 2
	fi
}
nftables_gen_conf () {
	cat <<-EOF
	#!/usr/sbin/nft -f
	flush ruleset
	table inet coderaft {
	        set ban_v4 {
	               type ipv4_addr
	               flags timeout
	        }
	        set ban_v6 {
	                type ipv6_addr
	                flags timeout
	        }
	        chain pre {
	                type filter hook prerouting priority 0
	                policy accept
	                iifname "lo" ip saddr 127.0.0.0/8 accept
	EOF
	if [ ! -z "$VLAN_IFACE" ] && [ ! -z "$VLAN_SUBNET" ]; then
	cat <<-EOF
	                iifname "$VLAN_IFACE" ip saddr $VLAN_SUBNET accept
	EOF
	fi
	cat <<-EOF
	                ip saddr {
	                        0.0.0.0/8,
	                        10.0.0.0/8,
	                        127.0.0.0/8,
	                        169.254.0.0/16,
	                        172.16.0.0/12,
	                        192.0.2.0/24,
	                        192.168.0.0/16,
	                        224.0.0.0/3,
	                        240.0.0.0/5 } drop
	                ct state invalid drop
	                tcp flags != syn / fin,syn,rst,ack ct state new drop
	                tcp flags fin,syn,rst,psh,ack,urg / fin,syn,rst,psh,ack,urg drop
	                tcp flags ! fin,syn,rst,psh,ack,urg drop
	                tcp flags fin,psh,urg / fin,syn,rst,psh,ack,urg drop
	                tcp flags fin / fin,ack drop
	                tcp flags fin,syn / fin,syn drop
	                tcp flags syn,rst / syn,rst drop
	                tcp flags fin,rst / fin,rst drop
	                tcp flags urg / ack,urg drop
	                tcp flags psh / psh,ack drop
	                #meta l4proto tcp ct state new # tcpmss match 1501:65535  drop
	        }
	        chain in {
	                type filter hook input priority 0
	                policy drop
	                iifname "lo" accept
	                fib daddr type broadcast drop
	                fib daddr type multicast drop
	                fib daddr type anycast drop
	                ip saddr @ban_v4 drop
	                ip6 saddr @ban_v6 drop
	                icmp type {
	                        echo-reply,
	                        destination-unreachable,
	                        time-exceeded } accept
	                icmp type echo-request goto in_icmp
	                icmpv6 type {
	                        destination-unreachable,
	                        packet-too-big,
	                        time-exceeded,
	                        echo-reply } accept
	                        icmpv6 type echo-request goto in_icmp
	                meta nfproto ipv4 tcp dport 22 ct state new goto in_ssh
	EOF
	if [ ! -z $HTTP_SERVER ]; then
	cat <<-EOF
	                tcp dport 80 accept
	                tcp dport 443 accept
	EOF
	fi
	cat <<-EOF
	                ct state related,established accept
	        }
	        chain in_icmp {
	                limit rate 55/minute burst 3 packets accept;
	                add @ban_v4 { ip saddr timeout 5m };
	                add @ban_v6 { ip6 saddr timeout 5m };
	                log prefix "nftables[in_icmp] ban "
	                drop;
	        }
	        chain in_ssh {
	                limit rate 5/minute burst 3 packets accept;
	                add @ban_v4 { ip saddr timeout 1h };
	                log prefix "nftables[in_ssh] ban "
	                drop;
	        }
	}
	EOF
}
# nftables-ubuntu.bash e8b081de 
nftables_setup_ubuntu () {
	if [ $DIST_VER_MAJOR -lt 22 ]; then
		echo "(Error) Requires Ubuntu 22 or more recent."
		exit 2
	fi
}
nftables_install () {
	NFTABLES_CONF_TMPFILE=$(mktemp -t .nftables.conf.XXXX)
	echo "Generating config"
	nftables_gen_conf > $NFTABLES_CONF_TMPFILE
	log_debug_file $NFTABLES_CONF_TMPFILE
	echo "Testing config"
	nft -c -f $NFTABLES_CONF_TMPFILE
	if [ $? -eq 0 ]; then
		echo "Success"
		cp --backup=t $NFTABLES_CONF_TMPFILE /etc/nftables.conf
		chmod +x /etc/nftables.conf
		nft -f /etc/nftables.conf
	else
		echo "(Error) While testing config"
		exit 1
	fi
	rm $NFTABLES_CONF_TMPFILE
}
NFTABLES=1
# nginx.bash 68cf2bee 
HTTP_SERVER=nginx
ENDPOINTS=()
nginx_setup () {
	prompt_input "Domains (domain.tld ..)" DOMAINS
	if [ -z "$DOMAINS" ]; then
		log_error "Please provide DOMAINS=domain.tld domain.tld .."
	fi
}
nginx_finish () {
	echo "Generating config"
	NGINX_SITE_FILE="/etc/nginx/sites-available/$RAFT_ID"
	if [ -f "$NGINX_SITE_FILE" ]; then
		NGINX_SITE_FILE_BKP=$(cat $NGINX_SITE_FILE)
	fi
	nginx_gen_site_conf > $NGINX_SITE_FILE
	log_debug_file $NGINX_SITE_FILE
	cp -sf $NGINX_SITE_FILE /etc/nginx/sites-enabled/
	echo "Testing config"
	nginx -t
	if [ $? -eq 0 ]; then
		echo "Success"
		service nginx reload
	else
		echo "$NGINX_SITE_FILE_BKP" > $NGINX_SITE_FILE
		echo "(Error) While testing config (reverted)"
		exit 1
	fi
}
nginx_get_ver () {
	local OUT=$(nginx -v 2>&1)
	if [ $? -eq 0 ]; then
		echo $(echo $OUT | awk 'match($0, /([0-9]+\.[0-9]+\.[0-9]+)/, g) {print g[1]}')
	fi
}
nginx_gen_site_conf () {
	cat <<-EOF
	server {
	        listen 80;
	        listen [::]:80;
	EOF
	echo -n "        server_name"
	for DOMAIN in $DOMAINS; do
		echo -n " .$DOMAIN"
	done
	echo ";"
	cat <<-EOF
	        return 301 https://\$host\$request_uri;
	}
	EOF
	for DOMAIN in $DOMAINS; do
		DOMAIN_NAME=${DOMAIN%.*}
		DOMAIN_SOCK_FILE=${DOMAIN_NAME//./_}
		cat <<-EOF
		server {
		        listen 443 ssl http2;
		        listen [::]:443 ssl http2;
		        server_name .$DOMAIN;
		        ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem;
		        ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;
		        ssl_protocols TLSv1.2 TLSv1.3;
		EOF
		for ENDPOINT in ${ENDPOINTS[@]}; do
			ENDPOINT_PATH=${ENDPOINT%%>*}
			ENDPOINT_TARGET=${ENDPOINT#*>}
			cat <<-EOF
		        location $ENDPOINT_PATH {
		                proxy_pass $ENDPOINT_TARGET;
		                proxy_redirect off;
		                proxy_http_version 1.1;
		                proxy_set_header Upgrade \$http_upgrade;
		                proxy_set_header Connection "";
		                proxy_set_header Host \$http_host;
		                proxy_set_header X-NginX-Proxy true;
		                proxy_set_header X-Real-IP \$remote_addr;
		                proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
		                proxy_set_header X-Forwarded-Proto \$scheme;
		        }
			EOF
		done
		cat <<-EOF
		}
		EOF
	done
}
nginx_add_endpoint () {
	local LOCATION=$1
	local TARGET=$2
	ENDPOINTS+=("$LOCATION>$TARGET")
}
# nginx-ubuntu.bash 19366fa1 
nginx_install_ubuntu () {
	echo "Probing nginx..."
	NGINX_VER=$(nginx_get_ver)
	if [ -z "$NGINX_VER" ]; then
		echo "Installing nginx"
		apt-get install nginx -y
		NGINX_VER=$(nginx_get_ver)
	fi
	if [ -z "$NGINX_VER" ]; then
		echo "(Error) Could not probe nginx version."
		exit 2
	else
		echo "NGINX Version: $NGINX_VER"
	fi
}
NGINX=1
# letsencrypt.bash 1bf5d1e6 
SSLCERT=letsencrypt
certbot_snap_core_get_ver () {
	echo $(snap list | awk '$1 == "core" { print $2 }')
}
certbot_get_ver () {
	local OUT=$(certbot --version 2>&1)
        if [ $? -eq 0 ]; then
                echo $(echo $OUT | awk 'match($0, /([0-9]+\.[0-9]+\.[0-9]+)/, g) {print g[1]}')
        fi
}
certbot_dns_do_get_ver () {
	echo $(snap list | awk '$1 == "certbot-dns-digitalocean" { print $2 }')
}
letsencrypt_setup () {
	prompt_input "Certificate Email" CERT_EMAIL
	if [ -z "$CERT_EMAIL" ]; then
		log_error "Please provide CERT_EMAIL=realemail@domain.tld"
	fi
	if [ -z $(command -v snap) ]; then
		log_error "Command snap not found"
	fi
}
letsencrypt_install () {
	echo "Setup snap"
	SNAP_CORE_VER=$(certbot_snap_core_get_ver)
	if [ -z "$SNAP_CORE_VER" ]; then
		snap install core
	else
		SNAP_CORE_REFRESH=1
	fi
	SNAP_CORE_VER=$(certbot_snap_core_get_ver)
	echo "Probing certbot..."
	CERTBOT_VER=$(certbot_get_ver)
	if [ -z "$CERTBOT_VER" ]; then
	        echo "Installing certbot"
		if [ ! -z "$SNAP_CORE_REFRESH" ]; then
			snap refresh core
		fi
		snap install --classic certbot
		snap set certbot trust-plugin-with-root=ok
	       	CERTBOT_VER=$(certbot_get_ver)
	fi
	CERTBOT_DNS_DO_VER=$(certbot_dns_do_get_ver)
	if [ -z "$CERTBOT_DNS_DO_VER" ] && [ "$PLAT_ID" = "do" ]; then
	        echo "Installing certbot-dns-digitalocean"
		snap install certbot-dns-digitalocean
		CERTBOT_DNS_DO_VER=$(certbot_dns_do_get_ver)
	fi
	if [ -z "$CERTBOT_VER" ]; then
	        echo "(Error) Could not probe certbot version."
	        exit 2
	else
	        echo "Certbot Version: $CERTBOT_VER"
	fi
	CERTBOT_CHALLENGE=
	if [ "$PLAT_ID" = "do" ]; then
		if [ -z "$DO_TOKEN" ]; then
			log_warn "You can provide DO_TOKEN for automated DNS validation"
		else
			echo "Using DigitalOcean API for DNS validation"
			CREDENTIALS_FILE="/root/.certbot_digitalocean.ini"
			echo "dns_digitalocean_token = $DO_TOKEN" > $CREDENTIALS_FILE
			chmod go-rwx $CREDENTIALS_FILE
			CERTBOT_CHALLENGE="--dns-digitalocean --dns-digitalocean-credentials $CREDENTIALS_FILE"
		fi
	fi
	if [ -z "$CERTBOT_CHALLENGE" ] && [ ! -z "$NGINX" ]; then
		echo "Using NGINX for DNS validation"
		CERTBOT_CHALLENGE="--nginx"
	fi
	if [ -z "$CERTBOT_CHALLENGE" ]; then
		CERTBOT_CHALLENGE="--manual"
	fi
	for DOMAIN in $DOMAINS; do
		if [ ! -d "/etc/letsencrypt/live/$DOMAIN" ]; then
			echo "Issuing certificate for $DOMAIN"
			certbot certonly $CERTBOT_CHALLENGE -n --agree-tos -m $CERT_EMAIL -d $DOMAIN -d www.$DOMAIN
		else
			OUT=$(cat /etc/letsencrypt/live/$DOMAIN/cert.pem | openssl x509 -noout -enddate)
			VALID_UNTIL=$(echo $OUT | awk -F= '{ print $2 }')
			echo "Skipping $DOMAIN"
			echo "Certificate valid until $VALID_UNTIL"
			echo "${BOLD}Consider running 'certbot renew'${NORMAL}"
		fi
	done
}
LETSENCRYPT=1
# nodejs.bash cf08d5de 
nodejs_setup () {
	prompt_input "Node.js Version (18.x)" NODEJS_PKG_VER "18.x"
}
nodejs_install () {
	echo "Probing Node.js ..."
	NODEJS_VER="$(nodejs_get_ver)"
	if [ ! -z "$NODEJS_VER" ]; then
		echo "Node.js Version: $NODEJS_VER"
	fi
}
nodejs_get_ver () {
	local OUT=$(node -v 2>&1)
	if [ $? -eq 0 ]; then
		echo $(echo $OUT | awk 'match($0, /([0-9]+\.[0-9]+\.[0-9]+)/, g) {print g[1]}')
	fi
}
# nodejs-ubuntu.bash 3392fbaf 
nodejs_install_ubuntu () {
	NODEJS_APT_SOURCE_FILE="${APT_SOURCES_DIR}/nodesource.list"
	if [ ! -f "$NODEJS_APT_SOURCE_FILE" ]; then
		echo "Fetching nodesource script"
		curl -fsSL https://deb.nodesource.com/setup_${NODEJS_PKG_VER} | bash -
	else
		echo "Nodesource repository already added"
	fi
	if [ -z "$NODEJS_VER" ]; then
		apt-get install -y nodejs
	else
		echo "${BOLD}Consider running 'apt-get update && apt-get -y install nodejs'${NORMAL}"
	fi
}
NODEJS=1
# mongodb.bash 4467d795 
mongodb_setup () {
	prompt_input "MongoDB Version (6.0)" MONGODB_PKG_VER "6.0"
}
mongodb_install () {
	echo "Probing MongoDB..."
	MONGODB_VER="$(mongodb_get_ver)"
	if [ ! -z "$MONGODB_VER" ]; then
		echo "MongoDB Version: $MONGODB_VER"
	fi
}
mongodb_get_ver () {
	local OUT=$(mongod --version 2>&1)
	if [ $? -eq 0 ]; then
		echo $(echo $OUT | awk 'NR==1 && match($0, /([0-9]+\.[0-9]+\.[0-9]+)/, g) {print g[1]}')
	fi
}
# mongodb-ubuntu.bash 38be0936 
mongodb_install_ubuntu () {
	MONGODB_APT_SOURCE_FILE="$APT_SOURCES_DIR/mongodb-org-${MONGODB_PKG_VER}.list"
	MONGODB_KEY_FILE="$KEYRING_DIR/mongodb.gpg"
	if [ ! -f "$MONGODB_APT_SOURCE_FILE" ]; then
		echo "Importing repository public keys"
		curl -sL https://www.mongodb.org/static/pgp/server-${MONGODB_PKG_VER}.asc | gpg --dearmor | tee $MONGODB_KEY_FILE >/dev/null
		if [ "$DIST_CODENAME" == "jammy" ]; then
			log_warn "Adding impish-security for libssl1.1 compat"
			echo "deb http://old-releases.ubuntu.com/ubuntu impish-security main" > $APT_SOURCES_DIR/impish-security.list
			log_warn "Adding repository source ubuntu/focal"
			echo "deb [signed-by=$MONGODB_KEY_FILE] https://repo.mongodb.org/apt/ubuntu focal/mongodb-org/${MONGODB_PKG_VER} multiverse" > $MONGODB_APT_SOURCE_FILE
		else
			echo "Adding repository source ubuntu/$DIST_CODENAME"
			echo "deb [signed-by=$MONGODB_KEY_FILE] https://repo.mongodb.org/apt/ubuntu ${DIST_CODENAME}/mongodb-org/${MONGODB_PKG_VER} multiverse" > $MONGODB_APT_SOURCE_FILE
		fi
	fi
	if [ -z "$MONGODB_VER" ]; then
		apt-get update
		if [ "$DIST_CODENAME" == "jammy" ]; then
			log_warn "Installing libssl1.1"
			apt-get install libssl1.1
		fi
		apt-get install -y mongodb-org
		# This is to prevent unintended upgrades
		echo "mongodb-org hold" | sudo dpkg --set-selections
		echo "mongodb-org-database hold" | sudo dpkg --set-selections
		echo "mongodb-org-server hold" | sudo dpkg --set-selections
		echo "mongodb-mongosh hold" | sudo dpkg --set-selections
		echo "mongodb-org-mongos hold" | sudo dpkg --set-selections
		echo "mongodb-org-tools hold" | sudo dpkg --set-selections
		systemctl enable mongod
		systemctl start mongod
	else
		echo "${BOLD}Consider manually updating mongodb${NORMAL}"
	fi
}
MONGODB=1
# git.bash e8bff3b5 
git_install () {
	echo "Probing Git..."
	GIT_VER="$(git_get_ver)"
	if [ ! -z "$GIT_VER" ]; then
		echo "Git Version: $GIT_VER"
	fi
}
git_get_ver () {
	local OUT=$(git --version 2>&1)
	if [ $? -eq 0 ]; then
		echo $(echo $OUT | awk 'match($0, /([0-9]+\.[0-9]+\.[0-9]+)/, g) {print g[1]}')
	fi
}
# git-ubuntu.bash 2996f7af 
git_install_ubuntu () {
	if [ -z "$GIT_VER" ]; then
		apt-get install git
	fi
}
GIT=1
GIT_CLONE_DUMMY_COMMIT=29fd4d716a799b3f7a32fca88b684e20b4f78aa3
# git-clone.bash bc0bd1cd 
git_clone_setup () {
	prompt_input "Git clone repository (coderaft-dummy)" GIT_CLONE_REPOSITORY "https://github.com/diogocasado/coderaft-dummy.git"
	if [ ! -z $GIT_CLONE_REPOSITORY ]; then
		GIT_CLONE_REPOSITORY_NAME=$(echo "$GIT_CLONE_REPOSITORY" | awk 'match($0, /.+\/([A-Za-z0-9\-_]+)\.git$/, g) {print g[1]}')
		prompt_input "Repository dir (/home/${GIT_CLONE_REPOSITORY_NAME})" GIT_CLONE_DIR "/home/${GIT_CLONE_REPOSITORY_NAME}"
		GIT_CLONE_COMMIT_DEFAULT="$GIT_CLONE_DUMMY_COMMIT"
		if [ -z "$GIT_CLONE_COMMIT_DEFAULT" ]; then
			GIT_CLONE_COMMIT_DEFAULT="null"
		fi
		prompt_input "Repository commit" GIT_CLONE_COMMIT "$GIT_CLONE_COMMIT_DEFAULT"
	fi
}
git_clone_install () {
	if [ ! -e "$GIT_CLONE_DIR" ]; then
		git clone "$GIT_CLONE_REPOSITORY" "$GIT_CLONE_DIR"
		if [ ! -z "$GIT_CLONE_COMMIT" ]; then
			cd $GIT_CLONE_DIR
			git reset --hard "$GIT_CLONE_COMMIT"
		fi
		if [ -f "$GIT_CLONE_DIR/coderaft" ]; then
			git_clone_unwrap "$GIT_CLONE_DIR/coderaft"
		fi
	else
		echo "Repository found at $GIT_CLONE_DIR"
		cd $GIT_CLONE_DIR
		git log -n 1 --oneline
		echo "${BOLD}Consider removing or 'git pull'${NORMAL}"
	fi
}
git_clone_unwrap () {
	FILE=$1
	local SYSTEMD_PATH=/usr/lib/systemd/system
	unset SERVICE
	unset DESCRIPTION
	unset START
	unset LOCATION
	unset PROXY_PASS
	echo "Unwrap $FILE"
	. "$FILE"
	if [ -z "$SERVICE" ]; then
		SERVICE=$(dirname "$FILE")
		SERVICE=${SERVICE#*/}
	fi
	echo "Service: $SERVICE"
	[ ! -z "$DESCRIPTION" ] && echo "Description: $DESCRIPTION"
	if [ ! -z "$LOCATION" ] && [ ! -z "$PROXY_PASS" ]; then
		echo "Location: $LOCATION -> $PROXY_PASS ($SERVICE)"
		nginx_add_endpoint "$LOCATION" "$PROXY_PASS"
	fi
	[ -z "$START" ] && git_clone_probe_start_nodejs
	[ -z "$START" ] && log_error "Could not determine command to start service."
	echo "Start: $START"
	if [ -d "${SYSTEMD_PATH}" ]; then
		echo "$(git_clone_gen_systemd_unit)" > "$SYSTEMD_PATH/$SERVICE.service"
		systemctl start $SERVICE
		systemctl --no-pager -n5 status $SERVICE
		systemctl enable $SERVICE
	fi
}
git_clone_probe_start_nodejs () {
	local SERVICE_PATH="$(dirname $FILE)"
	local NODEJS_PATH="$(which node)"
	if [ ! -z "$NODEJS_PATH" ] && [ -f "$SERVICE_PATH/package.json" ]; then
		START="$NODEJS_PATH $SERVICE_PATH"
	fi
}
git_clone_gen_systemd_unit () {
	[ ! -z "$DESCRIPTION" ] && cat <<-EOF
	[Unit]
	Description=$DESCRIPTION
	EOF
	cat <<-EOF
	[Service]
	ExecStart=$START
	Restart=on-failure
	RestartSec=1
	[Install]
	WantedBy=multi-user.target
	EOF
}
GIT_CLONE=1
PADDLE_COMMIT=4748074dc60b9d395f0785399d39ee29441f1382
# paddle.bash 793fb45e 
paddle_setup () {
	prompt_input_yn "Configure Discord?" PADDLE_USE_DISCORD "y"
	prompt_input_yn "Configure GitHub?" PADDLE_USE_GITHUB "y"
	nginx_add_endpoint "/paddle" "http://unix:/run/paddle_http.sock"
}
paddle_install () {
	PADDLE_DIR="/home/coderaft-paddle"
	if [ ! -e "$PADDLE_DIR" ]; then
		git clone "https://github.com/diogocasado/coderaft-paddle" "$PADDLE_DIR"
		if [ ! -z "$PADDLE_COMMIT" ]; then
			cd $PADDLE_DIR
			git reset --hard "$PADDLE_COMMIT"
		fi
		("$PADDLE_DIR/install")
	else
		echo "Repository found at $PADDLE_DIR"
		cd $PADDLE_DIR
		git log -n 1 --oneline
		echo "${BOLD}Consider removing or 'git pull'${NORMAL}"
	fi
}
paddle_finish () {
	if [ ! -z "$SERVICE" ]; then
		if [ ! -z "$PADDLE_USE_DISCORD" ]; then
			prompt_input "Discord Url" PADDLE_DISCORD_URL
		fi
		if [ ! -z "$PADDLE_USE_GITHUB" ]; then
			PADDLE_GITHUB_DEF_URL_PATH="/$SERVICE"
			prompt_input "GitHub Url Path (${PADDLE_GITHUB_DEF_URL_PATH})" PADDLE_GITHUB_URL_PATH "$PADDLE_GITHUB_DEF_URL_PATH"
			prompt_input "GitHub Secret" PADDLE_GITHUB_SECRET
			PADDLE_HAS_GIT_WEBHOOKS=1
		fi
		if [ ! -z "$PADDLE_HAS_GIT_WEBHOOKS" ]; then
			prompt_input_yn "Use Git automation?" PADDLE_USE_GIT "y"
			if [ ! -z "$GIT_CLONE" ]; then
				PADDLE_GIT_PATH="$GIT_CLONE_REPOSITORY"
				PADDLE_GIT_REPO="$GIT_CLONE_REPOSITORY_NAME"
			else
				prompt_input "Git Repo Path" PADDLE_GIT_PATH
				PADDLE_GIT_ORIGIN=$(git -C ${PADDLE_GIT_PATH} config --get remote.origin.url)
				PADDLE_GIT_REPO=$(basename -s .git $PADDLE_GIT_ORIGIN)
			fi
		else
			PADDLE_USE_GIT=0
		fi
		if [ $PADDLE_USE_GIT -gt 0 ]; then
			echo "Git repository ${BOLD}${PADDLE_GIT_REPO}${NORMAL}:"
			prompt_input_yn "Perform git pull?" PADDLE_GIT_PULL "n"
			prompt_input_yn "Restart after pull?" PADDLE_GIT_RESTART "n"
		fi
		echo "Generate paddle config"
		log_debug_file "$PADDLE_DIR/local.js"
		echo "$(paddle_gen_local_config)" > "$PADDLE_DIR/local.js"
		systemctl start paddle
		systemctl --no-pager -n5 status paddle
		systemctl enable paddle
	fi
}
paddle_gen_local_config () {
	cat <<-EOF
	exports.config = (config) => {
	EOF
	[ ! -z "$PADDLE_USE_DISCORD" ] && [ ! -z "$PADDLE_DISCORD_URL" ] && cat <<-EOF
	    config.discord.url = '$PADDLE_DISCORD_URL';
	EOF
	cat <<-EOF
	    config.services.push({
	        name: '$SERVICE',
	        path: '$GIT_CLONE_DIR',
	        location: '$LOCATION',
	        proxyPass: '$PROXY_PASS',
	        publishStatsInterval: 60000,
	EOF
	[ ! -z "$PADDLE_USE_DISCORD" ] && cat <<-EOF
	        discord: {
	            url: config.discord.url,
	            log: [ 'INFO', 'GIT-PUSH', 'ISSUE', 'ISSUE-COMMENT' ]
	        },
	EOF
	[ ! -z "$PADDLE_USE_GITHUB" ] && cat <<-EOF
	        github: {
	            urlPath: '$PADDLE_GITHUB_URL_PATH',
	            secret: '$PADDLE_GITHUB_SECRET'
	        },
	EOF
	if [ $PADDLE_USE_GIT -gt 0 ]; then
		PADDLE_GIT_PULL_BOOL="false"
		if [ $PADDLE_GIT_PULL -gt 0 ]; then
			PADDLE_GIT_PULL_BOOL="true"
		fi
		PADDLE_GIT_RESTART_BOOL="false"
		if [ $PADDLE_GIT_RESTART -gt 0 ]; then
			PADDLE_GIT_RESTART_BOOL="true"
		fi
		cat <<-EOF
	        git: {
	            pull: ${PADDLE_GIT_PULL_BOOL},
	            restart: ${PADDLE_GIT_RESTART_BOOL}
	        }
		EOF
	fi
	cat <<-EOF
	    });
	}
	EOF
}
PADDLE=1
floatme
