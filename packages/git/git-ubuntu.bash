
git_install_ubuntu () {

	if [ -z "$GIT_VER" ]; then
		apt-get install git
	fi
}
