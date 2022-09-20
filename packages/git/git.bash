
git_install () {
	echo "Probing Git..."
	GIT_VER="$(git_get_ver)"

	if [ ! -z "$GIT_VER" ]; then
		echo "Git Version: $GIT_VER"
	fi
}

git_get_ver () {
	local OUT=$(git --version 2>&1)
	if [ $? -eq 0 ]; then
		echo $(echo $OUT | awk 'match($0, /([0-9]+\.[0-9]+\.[0-9]+)/, g) {print g[1]}')
	fi
}


