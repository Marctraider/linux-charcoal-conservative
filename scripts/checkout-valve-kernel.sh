#!/usr/bin/env bash
set -euo pipefail

# Check out the exact Linux tree named by Valve's linux-neptune-73 PKGBUILD.
# Usage: scripts/checkout-valve-kernel.sh [destination]
DEST="${1:-$PWD/linux-neptune-73}"
REPO="https://github.com/evlaV/linux-integration.git"
TAG="7.3.1-valve3"

command -v git >/dev/null || { echo "error: git is required" >&2; exit 1; }

if [[ -e "$DEST" ]]; then
  echo "error: destination already exists: $DEST" >&2
  echo "Choose a new path; this script never overwrites an existing tree." >&2
  exit 1
fi

git clone --depth 1 --branch "$TAG" --single-branch "$REPO" "$DEST"
cd "$DEST"

actual="$(git describe --exact-match --tags HEAD)"
[[ "$actual" == "$TAG" ]] || {
  echo "error: expected tag $TAG, got $actual" >&2
  exit 1
}

commit="$(git rev-parse HEAD)"
printf '%s\n' "$commit" | tee SOURCE_COMMIT
printf 'Checked out %s at %s\n' "$TAG" "$commit"
