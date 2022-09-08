
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
