
nodejs_install_ubuntu () {

	if [ ! -f /etc/apt/sources.list.d/nodesource.list ]; then
		echo "Fetching nodesource script"
		curl -fsSL https://deb.nodesource.com/setup_${NODEJS_VER} | bash -
	else
		echo "Nodesource repository already added"
	fi

	if [ -z "$NODEJS_VER" ]; then
		apt-get install -y nodejs
	else
		echo "${BOLD}Consider running 'apt-get update && apt-get -y install nodejs'${NORMAL}"
	fi
}

