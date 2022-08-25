#!/bin/sh

if [ -z "$RAFT" ]; then
	echo "Nope."
	exit 1
fi

echo "Generating config"
NGINX_SITE_FILE="/etc/nginx/sites-available/$RAFT_ID"

if [ -f "$NGINX_SITE_FILE" ]; then
	NGINX_SITE_FILE_BKP=$(cat $NGINX_SITE_FILE)
fi

(. gen-nginx-site-conf.sh) > $NGINX_SITE_FILE
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
