#!/usr/bin/env bash
# Line above: run this file with bash, wherever bash is installed

set -euo pipefail
# -e: stop the moment any command fails
# -u: stop if we use a variable that was never set (catches typos)
# -o pipefail: if any command in a pipe fails, the whole pipe counts as failed

SRC_DIR="${SRC_DIR:-/etc/letsencrypt/live/example.com}"
# Where certbot puts renewed certs. ${SRC_DIR:-default} = use SRC_DIR if given, else the default

TARGET_DIR="${TARGET_DIR:-/etc/nginx/certs}"
# Where the app reads its cert from. On Kasm this was /opt/kasm/current/certs

SERVICE="${SERVICE:-nginx}"
# The service to restart so it loads the new cert. On Kasm: the kasm_proxy container

timestamp="$(date +%Y%m%d-%H%M%S)"
# e.g. 20261123-133000, used to name the backup folder

if [[ ! -f "$SRC_DIR/fullchain.pem" || ! -f "$SRC_DIR/privkey.pem" ]]; then
  # -f checks a file exists. ! means "not". So: if either cert file is missing...
  echo "ERROR: certificate files not found in $SRC_DIR" >&2
  # >&2 sends the message to the error output, not normal output
  exit 1
  # exit with 1 = failure. A pipeline treats this as a red X
fi

mkdir -p "$TARGET_DIR/backup-$timestamp"
# make a backup folder. -p = no error if it already exists

cp "$TARGET_DIR"/*.pem "$TARGET_DIR/backup-$timestamp/" 2>/dev/null || true
# copy the old certs into the backup. 2>/dev/null hides the error if there are none yet
# || true = don't stop the script if there was nothing to back up

cp "$SRC_DIR/fullchain.pem" "$TARGET_DIR/cert.pem"
cp "$SRC_DIR/privkey.pem" "$TARGET_DIR/key.pem"
# put the new cert and private key where the app expects them

chmod 600 $TARGET_DIR/key.pem
# 600 = only the owner can read or write the private key. A security basic

systemctl restart "$SERVICE"
# restart nginx so it actually loads the new cert (the step that was missing on Kasm)

expiry="$(openssl x509 -enddate -noout -in "$TARGET_DIR/cert.pem")"
# read the expiry date out of the cert we just deployed

echo "Deployed certificate. $expiry"
# print proof it worked, e.g. "notAfter=Feb 21 2027"