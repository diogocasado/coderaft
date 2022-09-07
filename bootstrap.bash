#!/usr/bin/env -iS /bin/bash --noprofile --norc

#set -x

PATH=$(. /etc/environment; echo $PATH)
HOME="/root"
TMPDIR="/tmp"

if [ $EUID != 0 ]; then
	echo "Requires root. Sorry."
	exit 1
fi

VERBOSE=0
PROMPT=1
CONFIRM_PROMT=()

COLOR_DEBUG="36"
COLOR_WARN="33"
COLOR_ERROR="31"
COLOR_FILE="35"
COLOR_PROMPT="34 47"

log_color () {
	for C in "$@"; do
		echo -ne "\e[${C}m"
	done
}

log_debug () {
	if [ $VERBOSE -gt 0 ]; then
		log_color $COLOR_DEBUG
		echo "(Debug) $@"
		log_color 0
	fi
}

log_debug_file () {
	if [ $VERBOSE -gt 0 ]; then
		log_color $COLOR_DEBUG
		echo "(Debug) Listing file $1"
		log_color $COLOR_FILE
		cat $1
		log_color 0
	fi
}

log_warn () {
	log_color $COLOR_WARN
	echo "(Warning) $@"
	log_color 0
}

log_error () {
	log_color $COLOR_ERROR
	echo "(Error) $@"
	log_color 0
	exit 1
}

prompt_input () {
	CONFIRM_PROMPT+=("$2:${1% (*}")

	if [ $PROMPT -gt 0 ]; then
		log_color $COLOR_PROMPT
		while [ -z ${!2} ]; do
			read -rp "$1: " $2
			if [ ! -z "$3" ]; then
				if [ "$3" != "null" ] && [ -z "${!2}" ]; then
					local -n VAR="$2"
					VAR="$3"
				fi
				break
			fi

		done
		log_color 0
		echo -ne "\e[2K"
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

print_greet () {
	log_color 34
	echo "Coderaft - VPS server configurator"
	echo "https://github.com/diogocasado/coderaft"
	log_color 0
}

invoke_func () {
	if [ ! -z "$(type -t $1)" ]; then
		log_debug "Invoke $1"
		"$1"
	fi
}

bootstrap () {
	print_raft
	print_greet

	CPUS=$(lscpu | awk '/^CPU\(s\):/ { print $2 }')
	MEM=$(free | awk '/^Mem:/ { printf "%.0f%c", ($2>900000 ? $2/1000000 : $2/1000), ($2>900000 ? "G" : "M") }')

	invoke_func "platform_init"
	invoke_func "dist_init"
	invoke_func "raft_init"

	echo "Platform: $PLAT_DESC"
	echo "Size: $CPUS vCPU, $MEM"
	echo "Distribution: $DIST_NAME $DIST_VER"
	echo "Raft: $RAFT_ID"
	echo "Packages: $PKGS"

	invoke_func "platform_setup"
	invoke_func "dist_setup"
	invoke_func "raft_setup"

	for PKG in $PKGS; do
		invoke_func "${PKG,,}_setup"
		invoke_func "${PKG,,}_setup_${DIST_ID}"
	done

	log_debug "Prompts are ${CONFIRM_PROMPT[@]}"

	echo "Please review:"
	log_color 0 32
	for PAIR in "${CONFIRM_PROMPT[@]}"; do
		DESC="${PAIR#*:}"
		VAR="${PAIR%:*}"
		echo "$DESC: ${!VAR}"
	done
	log_color 0
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

