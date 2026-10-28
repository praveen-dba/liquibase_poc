#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/common.sh"
docker compose down
echo "PostgreSQL container stopped. The data volume was kept."
echo "To delete the data volume as well, run: make reset"
