#!/usr/bin/env -iS /bin/bash --noprofile --norc

#set -x

PATH=$(. /etc/environment; echo $PATH)
HOME="/root"
TMPDIR="/tmp"

if [ $EUID != 0 ]; then
	echo "Requires root. Sorry."
	exit 1
fi

PROMPT=1
CONFIRM_PROMT=()
VERBOSE=0

log_debug () {
	if [ $VERBOSE -gt 0 ]; then
		echo "(Debug) $@"
	fi
}

log_debug_file () {
	if [ $VERBOSE -gt 0 ]; then
		echo "(Debug) Listing file $1"
		cat $1
	fi
}

log_warn () {
	echo "(Warning) $@"
}

log_error () {
	echo "(Error) $@"
	exit 1
}

prompt_input () {
	CONFIRM_PROMPT+=("$2:${1% (*}")

	if [ $PROMPT -gt 0 ]; then
		while [ -z ${!2} ]; do
			read -p "$1: " $2
		done
	fi
}

print_raft () {
	cat <<-EOF 
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
}

invoke_func () {
	if [ ! -z "$(type -t $1)" ]; then
		log_debug "Invoke $1"
		"$1"
	fi
}

bootstrap () {

	print_raft

	invoke_func "dist_init"
	invoke_func "platform_init"
	invoke_func "raft_init"

	if [ -z "$CPU" ]; then
		CPUS=$(lscpu | awk '/^CPU\(s\):/ { print $2 }')
	fi

	if [ -z "$MEM" ]; then
		MEM=$(free | awk '/^Mem:/ { printf "%.0f%c", ($2>900000 ? $2/1000000 : $2/1000), ($2>900000 ? "G" : "M") }')
	fi

	echo "Platform: $PLAT_DESC"
	echo "Size: $CPUS vCPU, $MEM"
	echo "Distribution: $DIST_NAME $DIST_VER"
	echo "Raft: $RAFT_ID"
	echo "Packages: $PKGS"

	for PKG in $PKGS; do
		invoke_func "${PKG,,}_setup"
		invoke_func "${PKG,,}_setup_${DIST_ID}"
	done

	echo "Please review:"
	log_debug "Prompts are ${CONFIRM_PROMPT[@]}"
	for PAIR in "${CONFIRM_PROMPT[@]}"; do
		DESC="${PAIR#*:}"
		VAR="${PAIR%:*}"
		echo "$DESC: ${!VAR}"
	done
		read -p "Continue? (y/N): " CONTINUE && [[ $CONTINUE == [yY] || $CONTINUE == [yY][eE][sS] ]] || exit 1

	for PKG in $PKGS; do
		echo "== Install $PKG"
		invoke_func "${PKG,,}_install"
		invoke_func "${PKG,,}_install_${DIST_ID}"
	done

	for PKG in $PKGS; do
		invoke_func "${PKG,,}_finish"
	done

	invoke_func "platform_finish"
	invoke_func "dist_finish"
	invoke_func "raft_finish"

	echo "Done."
}

