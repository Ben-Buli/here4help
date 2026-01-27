#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC_DIR="$ROOT_DIR/backend/"
DST_DIR="$ROOT_DIR/backend_cpanel_deploy/"

if [[ ! -d "$SRC_DIR" ]]; then
  echo "Source not found: $SRC_DIR" >&2
  exit 1
fi

if [[ ! -d "$DST_DIR" ]]; then
  echo "Destination not found: $DST_DIR" >&2
  exit 1
fi

RSYNC_ARGS=(
  -a
  --human-readable
  --progress
  --exclude ".env"
  --exclude "storage/"
  --exclude "logs/"
  --exclude "cache/"
  --exclude "uploads/"
  --exclude "quarantine/"
)

DELETE_FLAG=""
DRY_RUN_FLAG=""

for arg in "$@"; do
  case "$arg" in
    --delete)
      DELETE_FLAG="--delete"
      ;;
    --dry-run)
      DRY_RUN_FLAG="--dry-run"
      ;;
    *)
      echo "Unknown option: $arg" >&2
      echo "Usage: $0 [--delete] [--dry-run]" >&2
      exit 1
      ;;
  esac
done

if ! command -v rsync >/dev/null 2>&1; then
  echo "rsync not found. Please install rsync or sync manually." >&2
  exit 1
fi

echo "Syncing backend -> backend_cpanel_deploy"
echo "Source: $SRC_DIR"
echo "Destination: $DST_DIR"

rsync "${RSYNC_ARGS[@]}" $DELETE_FLAG $DRY_RUN_FLAG "$SRC_DIR" "$DST_DIR"
