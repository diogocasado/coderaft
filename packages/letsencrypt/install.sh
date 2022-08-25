#!/bin/sh

if [ -z "$RAFT" ]; then
	echo "Nope."
	exit 1
fi

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

if [ -z $(command -v snap) ]; then
	echo "(Error) Command snap not found"
	exit 2
fi

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

if [ -z "$DOMAINS" ]; then
	echo "(Error) Please provide DOMAINS=yourdomain.tld anotherdomain.tld"
	exit 1
fi

if [ -z "$CERT_EMAIL" ]; then
	echo "(Error) Please provide CERT_EMAIL=realemail@domain.tld"
	exit 1
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
