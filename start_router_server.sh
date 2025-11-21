#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Here4Help PHP router server"
echo "==========================="
echo "Working directory : $ROOT_DIR"
echo "Start time        : $(date '+%Y-%m-%d %H:%M:%S')"
echo

cd "$ROOT_DIR"
php -S localhost:8000 router.php
