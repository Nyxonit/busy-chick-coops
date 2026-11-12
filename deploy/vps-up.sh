#!/usr/bin/env bash
# Put the Busy Chick Coops storefront on an Ubuntu VPS with nginx.
# Safe to re-run. Removes only Ubuntu's packaged welcome site.
#
#   sudo bash deploy/vps-up.sh
#   sudo CERTBOT_EMAIL=you@example.com bash deploy/vps-up.sh --https
#
# --https asks Let's Encrypt for a certificate. DNS for every name in
# deploy/nginx-busy-chick.conf must already point at this machine, and
# ports 80 and 443 must be reachable. Skip --https while the domain is
# still proxied to a dead origin (Cloudflare error 521).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WEBROOT=/var/www/busy-chick-coops
SITE_NAME=busy-chick-coops
HTTPS=0

for arg in "$@"; do
  case "$arg" in
    --https) HTTPS=1 ;;
    -h|--help)
      sed -n '2,12p' "$0"
      exit 0
      ;;
    *)
      echo "Unknown argument: $arg" >&2
      exit 2
      ;;
  esac
done

if [[ "${EUID}" -ne 0 ]]; then
  exec sudo --preserve-env=CERTBOT_EMAIL bash "$0" "$@"
fi

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y nginx

mkdir -p "$WEBROOT"
install -m 644 "$ROOT/index.html" "$WEBROOT/index.html"
rm -rf "$WEBROOT/photos"
cp -a "$ROOT/photos" "$WEBROOT/photos"
chown -R root:root "$WEBROOT"
find "$WEBROOT" -type d -exec chmod 755 {} \;
find "$WEBROOT" -type f -exec chmod 644 {} \;

install -m 644 "$ROOT/deploy/nginx-busy-chick.conf" \
  "/etc/nginx/sites-available/${SITE_NAME}"
ln -sfn "/etc/nginx/sites-available/${SITE_NAME}" \
  "/etc/nginx/sites-enabled/${SITE_NAME}"

# A fresh Ubuntu image answers every hostname with the packaged welcome
# page. Drop that site so this storefront is what the IP serves. Leave
# the file in place when it has been edited, and never touch other vhosts.
DEFAULT_LINK=/etc/nginx/sites-enabled/default
if [[ -f "$DEFAULT_LINK" ]] && grep -q 'root /var/www/html' "$DEFAULT_LINK"; then
  rm -f "$DEFAULT_LINK"
fi

nginx -t
if [[ -d /run/systemd/system ]] && [[ "$(ps -p 1 -o comm=)" == "systemd" ]]; then
  systemctl enable nginx
  systemctl restart nginx
elif nginx -s reload 2>/dev/null; then
  :
else
  nginx
fi

if [[ "$HTTPS" -eq 1 ]]; then
  if [[ -z "${CERTBOT_EMAIL:-}" ]]; then
    echo "Set CERTBOT_EMAIL before using --https." >&2
    exit 2
  fi
  apt-get install -y certbot python3-certbot-nginx
  mapfile -t NAMES < <(awk '/server_name/ { for (i = 2; i <= NF; i++) { gsub(/;/, "", $i); if ($i != "_") print $i } }' \
    "/etc/nginx/sites-available/${SITE_NAME}")
  if [[ "${#NAMES[@]}" -eq 0 ]]; then
    echo "No server_name entries to request a certificate for." >&2
    exit 2
  fi
  args=(-n --agree-tos --email "$CERTBOT_EMAIL" --redirect --nginx)
  for name in "${NAMES[@]}"; do
    args+=(-d "$name")
  done
  certbot "${args[@]}"
  nginx -t
  if [[ -d /run/systemd/system ]] && [[ "$(ps -p 1 -o comm=)" == "systemd" ]]; then
    systemctl reload nginx
  else
    nginx -s reload
  fi
fi

echo "Busy Chick Coops is serving from ${WEBROOT} on port 80."
