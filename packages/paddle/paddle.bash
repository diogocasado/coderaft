
paddle_setup () {
	prompt_input "Webhooks (github)" PADDLE_WEBHOOKS "github"

	ENDPOINTS+=("/paddle>http://unix:/run/paddle.sock")
}

paddle_install () {
	PADDLE_DIR="$HOME/paddle"

	if [ ! -d "$PADDLE_DIR" ]
		git clone https://github.com/diogocasado/coderaft-paddle $PADDLE_DIR
		cd $PADDLE_DIR
		git reset --hard $PADDLE_COMMIT
		($PADDLE_DIR/install)
	fi
}
