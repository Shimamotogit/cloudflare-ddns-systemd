#!/usr/bin/env bash
set -Eeuo pipefail

readonly APP_USER="cloudflare-ddns"
readonly APP_GROUP="cloudflare-ddns"
readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly CONFIG_DIR="/etc/cloudflare-ddns"
readonly CONFIG_FILE="$CONFIG_DIR/config"
readonly TOKEN_FILE="$CONFIG_DIR/token"
readonly BIN_FILE="/usr/local/bin/cloudflare-ddns"
readonly SERVICE_FILE="/etc/systemd/system/cloudflare-ddns.service"
readonly TIMER_FILE="/etc/systemd/system/cloudflare-ddns.timer"

log() { printf 'install: %s\n' "$*"; }
die() { printf 'install: error: %s\n' "$*" >&2; exit 1; }

[[ ${EUID:-$(id -u)} -eq 0 ]] || die "run as root (sudo ./install.sh)"
[[ -f "$SCRIPT_DIR/src/cloudflare-ddns" ]] || die "run this installer from the repository checkout"

for cmd in systemctl useradd groupadd getent install awk; do
    command -v "$cmd" >/dev/null 2>&1 || die "required command not found: $cmd"
done

systemd_version="$(systemctl --version | awk 'NR == 1 {print $2}')"
[[ "$systemd_version" =~ ^[0-9]+$ ]] || die "could not determine systemd version"
(( systemd_version >= 247 )) || die "systemd 247+ is required (Ubuntu 22.04+ recommended)"

missing=()
command -v curl >/dev/null 2>&1 || missing+=(curl)
command -v jq >/dev/null 2>&1 || missing+=(jq)
command -v flock >/dev/null 2>&1 || missing+=(util-linux)

if (( ${#missing[@]} > 0 )); then
    die "missing dependencies: ${missing[*]} (Ubuntu: sudo apt install curl jq util-linux)"
fi

if ! getent group "$APP_GROUP" >/dev/null; then
    groupadd --system "$APP_GROUP"
fi

if ! id "$APP_USER" >/dev/null 2>&1; then
    useradd \
        --system \
        --gid "$APP_GROUP" \
        --no-create-home \
        --home-dir /nonexistent \
        --shell /usr/sbin/nologin \
        "$APP_USER"
fi

install -d -o root -g "$APP_GROUP" -m 0750 "$CONFIG_DIR"
install -o root -g root -m 0755 "$SCRIPT_DIR/src/cloudflare-ddns" "$BIN_FILE"
install -o root -g root -m 0644 "$SCRIPT_DIR/systemd/cloudflare-ddns.service" "$SERVICE_FILE"
install -o root -g root -m 0644 "$SCRIPT_DIR/systemd/cloudflare-ddns.timer" "$TIMER_FILE"

if [[ ! -e "$CONFIG_FILE" ]]; then
    install -o root -g "$APP_GROUP" -m 0640 "$SCRIPT_DIR/config/cloudflare-ddns.conf.example" "$CONFIG_FILE"
    log "created $CONFIG_FILE"
else
    chown root:"$APP_GROUP" "$CONFIG_FILE"
    chmod 0640 "$CONFIG_FILE"
    log "kept existing $CONFIG_FILE"
fi

if [[ ! -e "$TOKEN_FILE" ]]; then
    install -o root -g root -m 0600 /dev/null "$TOKEN_FILE"
    log "created empty $TOKEN_FILE"
else
    chown root:root "$TOKEN_FILE"
    chmod 0600 "$TOKEN_FILE"
    log "kept existing $TOKEN_FILE and enforced mode 0600"
fi

systemctl daemon-reload

# Fail closed: never start with placeholder IDs or an empty token.
if "$BIN_FILE" --check-config >/dev/null 2>&1 && [[ -s "$TOKEN_FILE" ]]; then
    systemctl enable --now cloudflare-ddns.timer
    log "installed and enabled cloudflare-ddns.timer"
else
    systemctl disable --now cloudflare-ddns.timer >/dev/null 2>&1 || true
    log "installed but timer is disabled until config and token are valid"
    log "then run: sudo systemctl enable --now cloudflare-ddns.timer"
fi
