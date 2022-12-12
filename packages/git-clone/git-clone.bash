
git_clone_setup () {
	prompt_input "Git clone repository (coderaft-dummy)" GIT_CLONE_REPOSITORY "https://github.com/diogocasado/coderaft-dummy.git"
	if [ ! -z $GIT_CLONE_REPOSITORY ]; then
		GIT_CLONE_REPOSITORY_NAME=$(echo "$GIT_CLONE_REPOSITORY" | awk 'match($0, /.+\/([A-Za-z0-9\-_]+)\.git$/, g) {print g[1]}')
		prompt_input "Repository dir (/home/${GIT_CLONE_REPOSITORY_NAME})" GIT_CLONE_DIR "/home/${GIT_CLONE_REPOSITORY_NAME}"
		
		GIT_CLONE_COMMIT_DEFAULT="$GIT_CLONE_DUMMY_COMMIT"
		if [ -z "$GIT_CLONE_COMMIT_DEFAULT" ]; then
			GIT_CLONE_COMMIT_DEFAULT="null"
		fi
		prompt_input "Repository commit" GIT_CLONE_COMMIT "$GIT_CLONE_COMMIT_DEFAULT"
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
		echo "${BOLD}Consider removing or 'git pull'${NORMAL}"
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
		systemctl enable $SERVICE
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
