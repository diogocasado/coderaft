#!/bin/sh

if [ -z "$RAFT" ]; then
	echo "Nope."
	exit 1
fi

if [ $DIST_VER_MAJOR -lt 22 ]; then
	echo "(Error) Requires Ubuntu 22 or more recent."
	exit 2
fi

if [ -z $(command -v nft) ]; then
	echo "(Error) Command nft not found"
	exit 2
fi

NFTABLES_CONF_TMPFILE=$(mktemp .nftables.conf.XXX)

echo "Generating config"
(. gen-nftables-conf.sh) > $NFTABLES_CONF_TMPFILE

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
echo "Done"
