
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

