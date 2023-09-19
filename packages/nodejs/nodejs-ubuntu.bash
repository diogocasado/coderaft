
nodejs_install_ubuntu () {

	NODESOURCE_KEY_URL="https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key"
	NODESOURCE_KEY_FILE="${APT_KEYRINGS_DIR}/nodesource.gpg"

	if [ ! -f "$NODESOURCE_KEY_FILE" ]; then
		echo "Importing nodesource repository public keys"
		curl -fsSL ${NODESOURCE_KEY_URL} | gpg --dearmor -o ${NODESOURCE_KEY_FILE}
	fi

	NODESOURCE_APT_SOURCE_FILE="${APT_SOURCES_DIR}/nodesource.list"
	if [ ! -f "$NODESOURCE_APT_SOURCE_FILE" ]; then
		echo "Adding nodesource repo"
		echo "deb [signed-by=${NODESOURCE_KEY_FILE}] https://deb.nodesource.com/node_${NODEJS_PKG_VER} nodistro main" > $NODESOURCE_APT_SOURCE_FILE
	fi

	if [ -z "$NODEJS_VER" ]; then
		apt-get install -y nodejs
	else
		echo "${BOLD}Consider running 'apt-get update && apt-get -y install nodejs'${NORMAL}"
	fi
}

