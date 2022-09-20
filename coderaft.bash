#!/bin/bash

#set -x

VERBOSE=0
PROMPT=1
CONFIRM_PROMT=()

if [ $EUID != 0 ]; then
	echo "Requires root. Sorry."
	exit 1
fi

if [ ! -z "$(command -v tput)" ]; then
	NCOLORS=$(tput colors)
	if [ $NCOLORS -ge 8 ]; then
		BOLD="$(tput bold)"
		UNDERLINE="$(tput smul)"
		STANDOUT="$(tput smso)"
		NORMAL="$(tput sgr0)"
		BLACK="$(tput setaf 0)"
		RED="$(tput setaf 1)"
		GREEN="$(tput setaf 2)"
		YELLOW="$(tput setaf 3)"
		BLUE="$(tput setaf 4)"
		MAGENTA="$(tput setaf 5)"
		CYAN="$(tput setaf 6)"
		WHITE="$(tput setaf 7)"
		_BLACK="$(tput setab 0)"
		_RED="$(tput setab 1)"
		_GREEN="$(tput setab 2)"
		_YELLOW="$(tput setab 3)"
		_BLUE="$(tput setab 4)"
		_MAGENTA="$(tput setab 5)"
		_CYAN="$(tput setab 6)"
		_WHITE="$(tput setab 7)"
	fi
fi

log_debug() {
	if [ $VERBOSE -gt 0 ]; then
		echo "${CYAN}(Debug) $@ ${NORMAL}"
	fi
}

log_debug_file () {
	if [ $VERBOSE -gt 0 ]; then
		echo "${CYAN}(Debug) Listing file $1 ${MAGENTA}"
		cat $1
		echo "${NORMAL}"
	fi
}

log_warn () {
	echo "${YELLOW}(Warning) $@ ${NORMAL}"
}

log_error () {
	echo "${RED}(Error) $@ ${NORMAL}"
	exit 1
}

prompt_input () {
	CONFIRM_PROMPT+=("$2:${1% (*}")

	if [ $PROMPT -gt 0 ]; then
		echo -n "${BLUE}${_WHITE}"
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
		echo -n "${NORMAL}"
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
	echo -n "${BLUE}"
	echo "Coderaft - VPS server configurator"
	echo "https://github.com/diogocasado/coderaft"
	echo -n "${NORMAL}"
}

invoke_func () {
	if [ ! -z "$(type -t $1)" ]; then
		[ ! -z "$2" ] && echo "${BLUE}$2${NORMAL}"
		log_debug "Invoke $1"
		"$1"
	fi
}

floatme () {
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

	echo "Please review:${GREEN}"
	for PAIR in "${CONFIRM_PROMPT[@]}"; do
		DESC="${PAIR#*:}"
		VAR="${PAIR%:*}"
		echo "$DESC: ${!VAR}"
	done
	echo -n "${NORMAL}"
	read -p "Continue? (y/N): " CONTINUE && [[ $CONTINUE == [yY] || $CONTINUE == [yY][eE][sS] ]] || exit 1

	for PKG in $PKGS; do
		echo "${BLUE}== Install $PKG ${NORMAL}"
		invoke_func "${PKG,,}_install"
		invoke_func "${PKG,,}_install_${DIST_ID}"
	done

	for PKG in $PKGS; do
		invoke_func "${PKG,,}_finish" \
			"== Wrapping up ${PKG}"
	done

	echo "${BLUE}== Cleaning up${NORMAL}"
	invoke_func "platform_finish"
	invoke_func "dist_finish"
	invoke_func "raft_finish"

	echo "Done."
}

