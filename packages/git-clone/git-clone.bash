
git_clone_setup () {
	prompt_input "Git clone repository (dummy)" GIT_CLONE_REPOSITORY "https://github.com/diogocasado/coderaft-dummy.git"
	if [ ! -z $GIT_CLONE_REPOSITORY ]; then
		prompt_input "Repository dir (dummy)" GIT_CLONE_DIR "$HOME/dummy"
		prompt_input "Repository commit" GIT_CLONE_COMMIT "$GIT_CLONE_DUMMY_COMMIT"
	fi
}

git_clone_install () {
	if [ ! -e "$GIT_CLONE_DIR" ]; then
		git clone "$GIT_CLONE_REPOSITORY" "$GIT_CLONE_DIR"

		if [ ! -z "$GIT_CLONE_COMMIT" ]; then
			cd $GIT_CLONE_DIR
			git reset --hard "$GIT_CLONE_COMMIT"
		fi

		if [ -f "$GIT_CLONE_DIR/coderaft" ]; then
			git_clone_unwrap "$GIT_CLONE_DIR/coderaft"
		fi
	else
		echo "Repository found at $GIT_CLONE_DIR"
		cd $GIT_CLONE_DIR
		git log -n 1 --oneline
		log_warn "Consider removing or 'git pull'"
	fi
}

git_clone_unwrap () {
	FILE=$1

	local SYSTEMD_PATH=/usr/lib/systemd/system

	unset SERVICE
	unset DESCRIPTION
	unset START
	unset LOCATION
	unset PROXY_PASS

	echo "Unwrap $FILE"
	. "$FILE"

	if [ -z "$SERVICE" ]; then
		SERVICE=$(dirname "$FILE")
		SERVICE=${SERVICE#*/}
	fi
	echo "Service: $SERVICE"
	
	[ ! -z "$DESCRIPTION" ] && echo "Description: $DESCRIPTION"

	if [ ! -z "$LOCATION" ] && [ ! -z "$PROXY_PASS" ]; then
		echo "Location: $LOCATION -> $PROXY_PASS ($SERVICE)"
		nginx_add_endpoint "$LOCATION" "$PROXY_PASS"
	fi

	[ -z "$START" ] && git_clone_probe_start_nodejs
	[ -z "$START" ] && log_error "Could not determine command to start service."

	echo "Start: $START"

	if [ -d "${SYSTEMD_PATH}" ]; then
		echo "$(git_clone_gen_systemd_unit)" > "$SYSTEMD_PATH/$SERVICE.service"
		systemctl start $SERVICE
		systemctl --no-pager -n5 status $SERVICE
	fi
}

git_clone_probe_start_nodejs () {
	local SERVICE_PATH="$(dirname $FILE)"
	local NODEJS_PATH="$(which node)"

	if [ ! -z "$NODEJS_PATH" ] && [ -f "$SERVICE_PATH/package.json" ]; then
		START="$NODEJS_PATH $SERVICE_PATH"
	fi
}

git_clone_gen_systemd_unit () {
	[ ! -z "$DESCRIPTION" ] && cat <<-EOF
	[Unit]
	Description=$DESCRIPTION
	EOF

	cat <<-EOF
	[Service]
	ExecStart=$START
	Restart=on-failure
	RestartSec=1

	[Install]
	WantedBy=multi-user.target
	EOF
}
