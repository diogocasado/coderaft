#!/usr/bin/env -iS /bin/bash --noprofile --norc

#set -x

PATH=$(. /etc/environment; echo $PATH)
TMPDIR="/tmp"

OLD_PWD=$(pwd)
BASE_PATH=$(cd $(dirname "$0"); pwd)

PLATFORM_DIR="${BASE_PATH}/platforms"
DIST_DIR="${BASE_PATH}/dists"
RAFT_DIR="${BASE_PATH}/rafts"
PKG_DIR="${BASE_PATH}/packages"

if [ $# -lt 2 ]; then

cat <<EOF 

       I\\
       I \\
       I  \\
       I*--\\
       I  x \\
       I 404 \\
       I______\\
 ______I_________
 \\  \\        \\  \\  ^  ^
 ^^^^^^^^^^^^^^^^^    ^
EOF

	echo -e "\nUsage: $(basename $0) platform raft"

	echo -e "\nPlatforms"
	PLATFORM_FILES=$(ls -1 $PLATFORM_DIR)
	for PLATFORM_FILE in ${PLATFORM_FILES[@]}; do
		PLATFORM_NAME=${PLATFORM_FILE%%.*}
		PLATFORM_DESC=$(. $PLATFORM_DIR/$PLATFORM_FILE > /dev/null 2>&1; echo $PLAT_DESC )
		echo $PLATFORM_NAME: $PLATFORM_DESC
	done

	echo -e "\nRafts"
	RAFT_FILES=$(ls -1 $RAFT_DIR)
	for RAFT_FILE in ${RAFT_FILES[@]}; do
		RAFT_NAME=${RAFT_FILE%%.*}
		RAFT_DESC=$(. $RAFT_DIR/$RAFT_FILE > /dev/null 2>&1; echo $RAFT_DESC )
		echo $RAFT_NAME: $RAFT_DESC
	done

	echo
	exit 0
fi

PLATFORM=$1
RAFT=$2

cd "$BASE_PATH"

DIST_ID="unknown"
if [ -f "/etc/os-release" ]; then
	DIST_ID=$(. /etc/os-release; echo $ID)
else
	echo "(Error) Unable to find os-release file."
	exit 2
fi

# Distribution configuration file properties
# DIST_ID=
# DIST_VER=
# DIST_VER_MAJOR=
# DIST_VER_MINOR=
DIST_FILE="${DIST_DIR}/${DIST_ID}.conf"
if [ -f "$DIST_FILE" ]; then
	. $DIST_FILE
else
	echo "(Error) Unable to find dist ${DIST_ID}."
fi

# Platform configuration file properties
# PLAT_ID=Same as ID in /etc/os-release
# PLAT_URL=VPS provider webpage
# CPUS=Number of logic CPUs
# MEM=Rounded memory size e.g.: 8G, 1G, 512M
# VLAN_IFACE=VLAN interface (optional, used by nftables)
# VLAN_SUBNET=VLAN subnet (optional, used by nftables)
PLATFORM_FILE="${PLATFORM_DIR}/${PLATFORM}.conf"
if [ -f "$PLATFORM_FILE" ]; then
	. $PLATFORM_FILE
else
	echo "(Error) Unable to find platform ${PLATFORM}."
	exit 2
fi

if [ -z "$CPU" ]; then
	CPUS=$(lscpu | awk '/^CPU\(s\):/ { print $2 }')
fi

if [ -z "$MEM" ]; then
	MEM=$(free | awk '/^Mem:/ { printf "%.0f%c", ($2>900000 ? $2/1000000 : $2/1000), ($2>900000 ? "G" : "M") }')
fi

echo "Platform: $PLAT_DESC"
echo "Size: $CPUS vCPU, $MEM"

# Raft configuration file parameters
# RAFT_ID=Same as filename less extenstion
# RAFT_DESC=A nice description (optional, appears in usage)
# PKGS=List of packages to install
# ADDONS=List of built in tools to be configured (optional)
RAFT_FILE="${RAFT_DIR}/${RAFT}.conf"
if [ -f "$RAFT_FILE" ]; then
	. $RAFT_FILE
else
	echo "(Error) Unable to find raft ${RAFT}."
	exit 2
fi

RAFT_REQUIRED_PARAMS=("PKGS")
for PARAM in ${RAFT_REQUIRED_PARAMS[@]}; do
	if [ -z "$(eval echo \$$PARAM)" ]; then
		echo "(Error) Missing parameter ${PARAM}. Check raft file."
		exit 1
	fi
done

for PKG in $PKGS; do
	if [ ! -d "${PKG_DIR}/${PKG}" ]; then
		echo "(Error) Raft package ${PKG} not found."
		exit 2
	fi

	PKG_FILE="${PKG_DIR}/${PKG}/${PKG}.conf"
	if [ -f "$PKG_FILE" ]; then
		. "$PKG_FILE"
	fi
	
	eval "${PKG^^}=1"
done

for PKG in $PKGS; do
	echo "== Install $PKG"

	PKG_INSTALL_DIR="${PKG_DIR}/${PKG}"
	PKG_INSTALL_SCRIPT="${PKG_DIR}/${PKG}/install"
	PKG_INSTALL_FILES=("${PKG_INSTALL_SCRIPT}-${DIST_ID}${DIST_VER_MAJOR}.sh" "${PKG_INSTALL_SCRIPT}-${DIST_ID}.sh" "${PKG_INSTALL_SCRIPT}.sh")
	PKG_INSTALL_FILE=

	for FILE in ${PKG_INSTALL_FILES[@]}; do
		if [ -f "$FILE" ]; then
			PKG_INSTALL_FILE=$FILE
			break
		fi
	done

	if [ ! -z "$PKG_INSTALL_FILE" ]; then
		cd "$PKG_INSTALL_DIR"
		(. "$PKG_INSTALL_FILE")
	else
		echo "(Warning) No install script found for package ${PKG}."
	fi
done

cd "$OLD_PWD"
