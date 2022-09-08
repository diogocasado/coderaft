
mongodb_install_ubuntu () {

	MONGODB_APT_SOURCE_FILE="$APT_SOURCES_DIR/mongodb-org-${MONGODB_PKG_VER}.list"
	MONGODB_KEY_FILE="$KEYRING_DIR/mongodb.gpg"

	if [ ! -f "$MONGODB_APT_SOURCE_FILE" ]; then
		echo "Importing repository public keys"
		curl -sL https://www.mongodb.org/static/pgp/server-${MONGODB_PKG_VER}.asc | gpg --dearmor | tee $MONGODB_KEY_FILE >/dev/null

		if [ "$DIST_CODENAME" == "jammy" ]; then
			log_warn "Adding impish-security for libssl1.1 compat"
			echo "deb http://old-releases.ubuntu.com/ubuntu impish-security main" > $APT_SOURCES_DIR/impish-security.list
			log_warn "Adding repository source ubuntu/focal"
			echo "deb [signed-by=$MONGODB_KEY_FILE] https://repo.mongodb.org/apt/ubuntu focal/mongodb-org/${MONGODB_PKG_VER} multiverse" > $MONGODB_APT_SOURCE_FILE
		else
			echo "Adding repository source ubuntu/$DIST_CODENAME"
			echo "deb [signed-by=$MONGODB_KEY_FILE] https://repo.mongodb.org/apt/ubuntu ${DIST_CODENAME}/mongodb-org/${MONGODB_PKG_VER} multiverse" > $MONGODB_APT_SOURCE_FILE
		fi
	fi

	if [ -z "$MONGODB_VER" ]; then
		apt-get update
		
		if [ "$DIST_CODENAME" == "jammy" ]; then
			log_warn "Installing libssl1.1"
			apt-get install libssl1.1
		fi

		apt-get install -y mongodb-org

		# This is to prevent unintended upgrades
		echo "mongodb-org hold" | sudo dpkg --set-selections
		echo "mongodb-org-database hold" | sudo dpkg --set-selections
		echo "mongodb-org-server hold" | sudo dpkg --set-selections
		echo "mongodb-mongosh hold" | sudo dpkg --set-selections
		echo "mongodb-org-mongos hold" | sudo dpkg --set-selections
		echo "mongodb-org-tools hold" | sudo dpkg --set-selections

		systemctl enable mongod
		systemctl start mongod
	else
		echo "${BOLD}Consider manually updating mongodb${NORMAL}"
	fi
}
