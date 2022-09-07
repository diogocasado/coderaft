
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
