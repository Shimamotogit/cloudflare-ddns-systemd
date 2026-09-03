#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

bash -n "$ROOT/src/cloudflare-ddns"
bash -n "$ROOT/install.sh"
bash -n "$ROOT/uninstall.sh"
"$ROOT/src/cloudflare-ddns" --self-test

printf 'tests: passed\n'
