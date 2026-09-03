#!/usr/bin/env bash
set -Eeuo pipefail

readonly APP_USER="cloudflare-ddns"
readonly APP_GROUP="cloudflare-ddns"
PURGE=false

if [[ "${1:-}" == "--purge" ]]; then
    PURGE=true
elif [[ $# -gt 0 ]]; then
    printf 'Usage: sudo ./uninstall.sh [--purge]\n' >&2
    exit 2
fi

[[ ${EUID:-$(id -u)} -eq 0 ]] || { printf 'uninstall: error: run as root\n' >&2; exit 1; }

systemctl disable --now cloudflare-ddns.timer >/dev/null 2>&1 || true
rm -f /etc/systemd/system/cloudflare-ddns.timer /etc/systemd/system/cloudflare-ddns.service
rm -rf /etc/systemd/system/cloudflare-ddns.timer.d
rm -f /usr/local/bin/cloudflare-ddns
systemctl daemon-reload

if [[ "$PURGE" == true ]]; then
    rm -rf /etc/cloudflare-ddns /var/lib/cloudflare-ddns /run/cloudflare-ddns
    userdel "$APP_USER" >/dev/null 2>&1 || true
    groupdel "$APP_GROUP" >/dev/null 2>&1 || true
    printf 'uninstall: removed program, config/token, state, and service account\n'
else
    printf 'uninstall: removed program and units; kept config/token and state\n'
    printf 'uninstall: use --purge to remove secrets/state and the service account\n'
fi
