#!/bin/bash

cat <<EOF

server {
        listen 80;
        listen [::]:80;

EOF

	echo -n "	server_name"
for DOMAIN in $DOMAINS; do
	echo -n " .$DOMAIN"
done

cat <<EOF
;
        return 301 https://\$host\$request_uri;
}

EOF



for DOMAIN in $DOMAINS; do
	DOMAIN_NAME=${DOMAIN%.*}
	DOMAIN_SOCK_FILE=${DOMAIN_NAME//./_}

cat <<EOF
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

