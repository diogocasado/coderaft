
HTTPSVC=nginx

nginx_setup () {
	prompt_input "Domains (domain.tld ..)" DOMAINS

	if [ -z "$DOMAINS" ]; then
		log_error "Please provide DOMAINS=domain.tld domain.tld .."
	fi
}

nginx_finish () {
	echo "Generating config"
	NGINX_SITE_FILE="/etc/nginx/sites-available/$RAFT_ID"

	if [ -f "$NGINX_SITE_FILE" ]; then
		NGINX_SITE_FILE_BKP=$(cat $NGINX_SITE_FILE)
	fi

	nginx_gen_site_conf > $NGINX_SITE_FILE
	log_debug_file $NGINX_SITE_FILE

	cp -sf $NGINX_SITE_FILE /etc/nginx/sites-enabled/

	echo "Testing config"
	nginx -t

	if [ $? -eq 0 ]; then
		echo "Success"
		service nginx reload
	else
		echo "$NGINX_SITE_FILE_BKP" > $NGINX_SITE_FILE
		echo "(Error) While testing config (reverted)"
		exit 1
	fi
}

nginx_get_ver () {
	local OUT=$(nginx -v 2>&1)
	if [ $? -eq 0 ]; then
		echo $(echo $OUT | awk 'match($0, /([0-9]+\.[0-9]+\.[0-9]+)/, g) {print g[1]}')
	fi
}

nginx_gen_site_conf () {
	cat <<-EOF
	server {
	        listen 80;
	        listen [::]:80;
	EOF

	echo -n "        server_name"
	for DOMAIN in $DOMAINS; do
		echo -n " .$DOMAIN"
	done
	echo ";"

	cat <<-EOF
	        return 301 https://\$host\$request_uri;
	}
	EOF

	for DOMAIN in $DOMAINS; do
		DOMAIN_NAME=${DOMAIN%.*}
		DOMAIN_SOCK_FILE=${DOMAIN_NAME//./_}

		cat <<-EOF
		server {
		        listen 443 ssl http2;
		        listen [::]:443 ssl http2;

		        server_name .$DOMAIN;

		        ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem;
		        ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;
		        ssl_protocols TLSv1.2 TLSv1.3;

		        location / {
		                proxy_pass http://unix:/var/run/http_$DOMAIN_SOCK_FILE.sock;
		                proxy_redirect off;
		                proxy_http_version 1.1;
		                proxy_set_header Upgrade \$http_upgrade;
		                proxy_set_header Connection "";
		                proxy_set_header X-Real-IP \$remote_addr;
		                proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
		                proxy_set_header X-Forwarded-Proto \$scheme;
		                proxy_set_header Host \$http_host;
		                proxy_set_header X-NginX-Proxy true;
		        }
		}
		EOF
	done
}
