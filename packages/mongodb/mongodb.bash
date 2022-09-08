
mongodb_setup () {
	prompt_input "MongoDB Version (6.0)" MONGODB_PKG_VER "6.0"
}

mongodb_install () {
	echo "Probing MongoDB..."
	MONGODB_VER="$(mongodb_get_ver)"

	if [ ! -z "$MONGODB_VER" ]; then
		echo "MongoDB Version: $MONGODB_VER"
	fi
}

mongodb_get_ver () {
	local OUT=$(mongod --version 2>&1)
	if [ $? -eq 0 ]; then
		echo $(echo $OUT | awk 'NR==1 && match($0, /([0-9]+\.[0-9]+\.[0-9]+)/, g) {print g[1]}')
	fi
}


