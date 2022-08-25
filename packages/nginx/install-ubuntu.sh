#!/bin/sh

if [ -z "$RAFT" ]; then
	echo "Nope."
	exit 1
fi

_nginx_get_ver () {

	local OUT=$(nginx -v 2>&1)
	if [ $? -eq 0 ]; then
		echo $(echo $OUT | awk 'match($0, /([0-9]+\.[0-9]+\.[0-9]+)/, g) {print g[1]}')
	fi
}

echo "Probing nginx..."
NGINX_VER=$(_nginx_get_ver)

if [ -z "$NGINX_VER" ]; then
	echo "Installing nginx"
	apt-get install nginx -y
	NGINX_VER=$(_nginx_get_ver)
fi

if [ -z "$NGINX_VER" ]; then
	echo "(Error) Could not probe nginx version."
	exit 2
else
	echo "NGINX Version: $NGINX_VER"
fi

