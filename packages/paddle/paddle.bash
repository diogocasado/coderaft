
paddle_setup () {
	prompt_input "Webhooks (github)" PADDLE_WEBHOOKS "github"

	nginx_add_endpoint "/paddle" "http://unix:/run/paddle.sock"
}

paddle_install () {
	PADDLE_DIR="$HOME/paddle"

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
		log_warn "Consider removing or 'git pull'"
	fi
}
