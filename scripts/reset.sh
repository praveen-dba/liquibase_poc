#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/common.sh"
docker compose down -v
exec "$(dirname "$0")/up.sh"
