#!/usr/bin/env -iS /bin/bash --noprofile --norc
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

#set -x

PATH=$(. /etc/environment; echo $PATH)
HOME="/root"
TMPDIR="/tmp"

if [ $EUID != 0 ]; then
	echo "Requires root. Sorry."
	exit 1
fi

PROMPT=1
CONFIRM_PROMT=()
VERBOSE=1

log_debug () {
	if [ $VERBOSE -gt 0 ]; then
		echo "(Debug) $@"
	fi
}
log_debug_file () {
	if [ $VERBOSE -gt 0 ]; then
		echo "(Debug) Listing file $1"
		cat $1
	fi
}

log_warn () {
	echo "(Warning) $@"
}

log_error () {
	echo "(Error) $@"
	exit 1
}

prompt_input () {
	CONFIRM_PROMPT+=("$2:${1% (*}")

	if [ $PROMPT -gt 0 ]; then
		while [ -z ${!2} ]; do
			read -p "$1: " $2
		done
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

invoke_func () {
	if [ ! -z "$(type -t $1)" ]; then
		log_debug "Invoke $1"
		"$1"
	fi
}

bootstrap () {

	print_raft

	invoke_func "dist_init"
	invoke_func "platform_init"
	invoke_func "raft_init"

	if [ -z "$CPU" ]; then
		CPUS=$(lscpu | awk '/^CPU\(s\):/ { print $2 }')
	fi

	if [ -z "$MEM" ]; then
		MEM=$(free | awk '/^Mem:/ { printf "%.0f%c", ($2>900000 ? $2/1000000 : $2/1000), ($2>900000 ? "G" : "M") }')
	fi

	echo "Platform: $PLAT_DESC"
	echo "Size: $CPUS vCPU, $MEM"
	echo "Distribution: $DIST_NAME $DIST_VER"
	echo "Raft: $RAFT_ID"
	echo "Packages: $PKGS"

	for PKG in $PKGS; do
		invoke_func "${PKG,,}_setup"
		invoke_func "${PKG,,}_setup_${DIST_ID}"
	done

	echo "Please review:"
	log_debug "Prompts are ${CONFIRM_PROMPT[@]}"
	for PAIR in "${CONFIRM_PROMPT[@]}"; do
		DESC="${PAIR#*:}"
		VAR="${PAIR%:*}"
		echo "$DESC: ${!VAR}"
	done
		read -p "Continue? (y/N): " CONTINUE && [[ $CONTINUE == [yY] || $CONTINUE == [yY][eE][sS] ]] || exit 1

	for PKG in $PKGS; do
		echo "== Install $PKG"
		invoke_func "${PKG,,}_install"
		invoke_func "${PKG,,}_install_${DIST_ID}"
	done

	for PKG in $PKGS; do
		invoke_func "${PKG,,}_finish"
	done

	invoke_func "platform_finish"
	invoke_func "dist_finish"
	invoke_func "raft_finish"

	echo "Done."
}

# ubuntu.bash 695fdfa3 

DIST_ID=ubuntu
DIST_NAME=Ubuntu
DIST_DESC="Ubuntu is the modern, open source operating system on Linux for the enterprise server, desktop, cloud, and IoT."

dist_init () {
	DIST_VER=$(lsb_release -r | awk '{ print $2 }')
	DIST_VER_MAJOR=$(echo $DIST_VER | awk 'match($0, /([0-9]*)\./, m) { print m[1] }')
	DIST_VER_MINOR=$(echo $DIST_VER | awk 'match($0, /[0-9]*\.([0-9]*)/, m) { print m[1] }')
}
# digitalocean.bash 3513b4bd 

PLAT_ID=do
PLAT_DESC="DigitalOcean (https://digitalocean.com)"

VLAN_IFACE="eth0"
VLAN_SUBNET="10.132.0.0/16"

# webnodejs.bash c8b25cdf 
# vim: set syntax=sh

RAFT_ID=webnodejs
RAFT_DESC="A simple Node.js + MongoDB raft."
PKGS="nftables nginx letsencrypt"
#PKGS="mongodb nodejs pm2"
ADDONS=github

# nftables.bash ae2ada27 

FWEND=nftables

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

	if [ ! -z $HTTPSVC ]; then
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
	                log prefix "bftables[in_ssh] ban "
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
# nginx.bash 58d8fa0d 

HTTPSVC=nginx

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

		        location / {
		                proxy_pass http://unix:/var/run/http_$DOMAIN_SOCK_FILE.sock;
		                proxy_redirect off;
		                proxy_http_version 1.1;
		                proxy_set_header Upgrade \$http_upgrade;
		                proxy_set_header Connection "";
		                proxy_set_header X-Real-IP \$remote_addr;
		                proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
		                proxy_set_header X-Forwarded-Proto \$scheme;
		                proxy_set_header Host \$http_host;
		                proxy_set_header X-NginX-Proxy true;
		        }
		}
		EOF
	done
}
# nginx-ubuntu.bash 6f6e1136 

nginx_install () {
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
# letsencrypt.bash 27ff950c 

SSLCERT=letsencrypt

_snap_core_get_ver () {
	echo $(snap list | awk '$1 == "core" { print $2 }')
}

_certbot_get_ver () {
	local OUT=$(certbot --version 2>&1)
        if [ $? -eq 0 ]; then
                echo $(echo $OUT | awk 'match($0, /([0-9]+\.[0-9]+\.[0-9]+)/, g) {print g[1]}')
        fi
}

_certbot_dns_do_get_ver () {
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

	SNAP_CORE_VER=$(_snap_core_get_ver)
	if [ -z "$SNAP_CORE_VER" ]; then
		snap install core
	else
		SNAP_CORE_REFRESH=1
	fi
	SNAP_CORE_VER=$(_snap_core_get_ver)

	echo "Probing certbot..."
	CERTBOT_VER=$(_certbot_get_ver)

	if [ -z "$CERTBOT_VER" ]; then
	        echo "Installing certbot"
		if [ ! -z "$SNAP_CORE_REFRESH" ]; then
			snap refresh core
		fi
		snap install --classic certbot
		snap set certbot trust-plugin-with-root=ok

	       	CERTBOT_VER=$(_certbot_get_ver)
	fi

	CERTBOT_DNS_DO_VER=$(_certbot_dns_do_get_ver)
	if [ -z "$CERTBOT_VER" ] && [ "$PLAT_ID" = "do" ]; then
	        echo "Installing certbot-dns-digitalocean"
		snap install certbot-dns-digitalocean

		CERTBOT_DNS_DO_VER=$(_certbot_dns_do_get_ver)
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
			echo "(Warning) You should provide DO_TOKEN for automated DNS validation"
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
			echo "Consider running 'certbot renew'"
		fi
	done
}
LETSENCRYPT=1
bootstrap
