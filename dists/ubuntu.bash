
DIST_ID=ubuntu
DIST_NAME=Ubuntu
DIST_DESC="Ubuntu is the modern, open source operating system on Linux for the enterprise server, desktop, cloud, and IoT."

dist_init () {
	DIST_VER=$(lsb_release -r | awk '{ print $2 }')
	DIST_VER_MAJOR=$(echo $DIST_VER | awk 'match($0, /([0-9]*)\./, m) { print m[1] }')
	DIST_VER_MINOR=$(echo $DIST_VER | awk 'match($0, /[0-9]*\.([0-9]*)/, m) { print m[1] }')
}
