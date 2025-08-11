#!/usr/bin/env bash
set -euo pipefail

if [ $# -lt 2 ]; then
  echo "Usage: ./release.sh <version_tag> <new_pubspec_version> [\"release notes\"]"
  exit 1
fi

TAG="$1"
NEW_VER="$2"
NOTES="${3:-Release $TAG}"

sed -i "" "s/^version:.*/version: ${NEW_VER}/" pubspec.yaml

git add pubspec.yaml docs/
git commit -m "chore(release): ${TAG} - bump to ${NEW_VER}" || true

git tag -a "${TAG}" -m "${NOTES}"

git push origin main
git push origin "${TAG}"

echo "Released ${TAG} with version ${NEW_VER}"
