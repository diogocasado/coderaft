
nodejs_setup () {
	prompt_input "Node.js Version (18.x)" NODEJS_PKG_VER "18.x"
}

nodejs_install () {
	
	echo "Probing Node.js ..."
	NODEJS_VER="$(nodejs_get_ver)"

	if [ ! -z "$NODEJS_VER" ]; then
		echo "Node.js Version: $NODEJS_VER"
	fi
}

nodejs_get_ver () {
	local OUT=$(node -v 2>&1)
	if [ $? -eq 0 ]; then
		echo $(echo $OUT | awk 'match($0, /([0-9]+\.[0-9]+\.[0-9]+)/, g) {print g[1]}')
	fi
}


