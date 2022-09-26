
paddle_setup () {
	prompt_input "Webhooks (discord)" PADDLE_WEBHOOKS "discord"

	for WEBHOOK in "${PADDLE_WEBHOOKS}"; do
		[ "$WEBHOOK" == "discord" ] && PADDLE_USE_DISCORD=1
	done;

	nginx_add_endpoint "/paddle" "http://unix:/run/paddle_http.sock"
}

paddle_install () {
	PADDLE_DIR="/home/paddle"

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

		echo "Generate paddle config"
		log_debug_file "$PADDLE_DIR/local.js"
		echo "$(paddle_gen_local_config)" > "$PADDLE_DIR/local.js"

		systemctl start paddle
		systemctl --no-pager -n5 status paddle
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
	        gitPath: '$GIT_CLONE_DIR',
	        location: '$LOCATION',
	        proxyPass: '$PROXY_PASS',
	        publishStatsInterval: 60000,
	EOF
	[ ! -z "$PADDLE_USE_DISCORD" ] && [ ! -z "$PADDLE_DISCORD_URL" ] && cat <<-EOF
	        discord: {
	            url: config.discord.url
	        }
	EOF
	cat <<-EOF
	    });
	}
	EOF
}
