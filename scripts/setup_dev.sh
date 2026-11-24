#!/usr/bin/env bash
# setup_dev.sh - prepare the dev server so deploy_cert.sh has something real to do
set -euo pipefail
# stop on any error, unset variable, or failed pipe (same as before)

DOMAIN="${DOMAIN:-example.com}"
SRC_DIR="/etc/letsencrypt/live/$DOMAIN"
# the exact folder certbot uses for renewed certs
TARGET_DIR="/etc/nginx/certs"
# where nginx reads its cert (on Kasm: /opt/kasm/current/certs)

if ! command -v nginx >/dev/null 2>&1; then
  # "command -v nginx" checks if nginx is installed. >/dev/null 2>&1 hides its output
  dnf install -y nginx
  # dnf = Amazon Linux's package installer. -y = say yes automatically
fi
# only installs the first time, so running this script twice is safe (idempotent)

mkdir -p "$SRC_DIR" "$TARGET_DIR"
# create both folders if they don't exist

openssl req -x509 -newkey rsa:2048 -nodes -days 90 \
  -subj "/CN=$DOMAIN" \
  -keyout "$SRC_DIR/privkey.pem" \
  -out "$SRC_DIR/fullchain.pem"
# make a self-signed cert valid for 90 days (like Let's Encrypt) = our fake "renewal"
# -x509: make a certificate, not a request. -newkey rsa:2048: make a new 2048-bit key
# -nodes: don't password-protect the key. -subj: the name on the cert. \ = command continues

cat > /etc/nginx/conf.d/tls.conf <<NGINX
server {
    listen 443 ssl;
    server_name $DOMAIN;
    ssl_certificate     $TARGET_DIR/cert.pem;
    ssl_certificate_key $TARGET_DIR/key.pem;
    location / {
        return 200 "kasm-ops-pipeline dev OK\n";
    }
}
NGINX
# write an nginx config: listen for HTTPS on port 443, using the cert in TARGET_DIR,
# and reply "kasm-ops-pipeline dev OK" to every request
# <<NGINX ... NGINX = everything in between is written into the file

systemctl enable nginx
# start nginx automatically on boot. We don't start it here: deploy_cert.sh restarts it
# after the certs are in place, because nginx refuses to start without them