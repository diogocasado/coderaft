
nodejs_install_ubuntu () {
	curl -fsSL https://deb.nodesource.com/setup_${NODEJS_VER} | bash -
	apt-get install -y nodejs
}
