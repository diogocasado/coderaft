
paddle_setup () {
	prompt_input_yn "Configure Discord?" PADDLE_USE_DISCORD "y"
	prompt_input_yn "Configure GitHub?" PADDLE_USE_GITHUB "y"

	nginx_add_endpoint "/paddle" "http://unix:/run/paddle_http.sock"
}

paddle_install () {
	PADDLE_DIR="/home/coderaft-paddle"

	if [ ! -e "$PADDLE_DIR" ]; then
		git clone "https://github.com/diogocasado/coderaft-paddle" "$PADDLE_DIR"
		if [ ! -z "$PADDLE_COMMIT" ]; then
			cd $PADDLE_DIR
			git reset --hard "$PADDLE_COMMIT"
		fi

		("$PADDLE_DIR/install")
	else
		echo "Repository found at $PADDLE_DIR"
		cd $PADDLE_DIR
		git log -n 1 --oneline
		echo "${BOLD}Consider removing or 'git pull'${NORMAL}"
	fi
}

paddle_finish () {
	if [ ! -z "$SERVICE" ]; then

		if [ ! -z "$PADDLE_USE_DISCORD" ]; then
			prompt_input "Discord Url" PADDLE_DISCORD_URL
		fi

		if [ ! -z "$PADDLE_USE_GITHUB" ]; then
			PADDLE_GITHUB_DEF_URL_PATH="/$SERVICE"
			prompt_input "GitHub Url Path (${PADDLE_GITHUB_DEF_URL_PATH})" PADDLE_GITHUB_URL_PATH "$PADDLE_GITHUB_DEF_URL_PATH"
			prompt_input "GitHub Secret" PADDLE_GITHUB_SECRET
			PADDLE_HAS_GIT_WEBHOOKS=1
		fi

		if [ ! -z "$PADDLE_HAS_GIT_WEBHOOKS" ]; then
			prompt_input_yn "Use Git automation?" PADDLE_USE_GIT "y"
			if [ ! -z "$GIT_CLONE" ]; then
				PADDLE_GIT_PATH="$GIT_CLONE_REPOSITORY"
				PADDLE_GIT_REPO="$GIT_CLONE_REPOSITORY_NAME"
			else
				prompt_input "Git Repo Path" PADDLE_GIT_PATH
				PADDLE_GIT_ORIGIN=$(git -C ${PADDLE_GIT_PATH} config --get remote.origin.url)
				PADDLE_GIT_REPO=$(basename -s .git $PADDLE_GIT_ORIGIN)
			fi
		else
			PADDLE_USE_GIT=0
		fi

		if [ $PADDLE_USE_GIT -gt 0 ]; then
			echo "Git repository ${BOLD}${PADDLE_GIT_REPO}${NORMAL}:"
			prompt_input_yn "Perform git pull?" PADDLE_GIT_PULL "n"
			prompt_input_yn "Restart after pull?" PADDLE_GIT_RESTART "n"
		fi

		echo "Generate paddle config"
		log_debug_file "$PADDLE_DIR/local.js"
		echo "$(paddle_gen_local_config)" > "$PADDLE_DIR/local.js"

		systemctl start paddle
		systemctl --no-pager -n5 status paddle
		systemctl enable paddle
	fi
}

paddle_gen_local_config () {
	cat <<-EOF
	exports.config = (config) => {
	EOF
	[ ! -z "$PADDLE_USE_DISCORD" ] && [ ! -z "$PADDLE_DISCORD_URL" ] && cat <<-EOF
	    config.discord.url = '$PADDLE_DISCORD_URL';
	EOF
	cat <<-EOF
	    config.services.push({
	        name: '$SERVICE',
	        path: '$GIT_CLONE_DIR',
	        location: '$LOCATION',
	        proxyPass: '$PROXY_PASS',
	        publishStatsInterval: 60000,
	EOF
	[ ! -z "$PADDLE_USE_DISCORD" ] && cat <<-EOF
	        discord: {
	            url: config.discord.url,
	            log: [ 'INFO', 'GIT-PUSH', 'ISSUE', 'ISSUE-COMMENT' ]
	        },
	EOF
	[ ! -z "$PADDLE_USE_GITHUB" ] && cat <<-EOF
	        github: {
	            urlPath: '$PADDLE_GITHUB_URL_PATH',
	            secret: '$PADDLE_GITHUB_SECRET'
	        },
	EOF
	if [ $PADDLE_USE_GIT -gt 0 ]; then
		PADDLE_GIT_PULL_BOOL="false"
		if [ $PADDLE_GIT_PULL -gt 0 ]; then
			PADDLE_GIT_PULL_BOOL="true"
		fi
		PADDLE_GIT_RESTART_BOOL="false"
		if [ $PADDLE_GIT_RESTART -gt 0 ]; then
			PADDLE_GIT_RESTART_BOOL="true"
		fi
		cat <<-EOF
	        git: {
	            pull: ${PADDLE_GIT_PULL_BOOL},
	            restart: ${PADDLE_GIT_RESTART_BOOL}
	        }
		EOF
	fi
	cat <<-EOF
	    });
	}
	EOF
}
