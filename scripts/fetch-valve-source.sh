#!/usr/bin/env bash
set -euo pipefail

# Fetch and authenticate the exact Valve SteamOS 3.10 kernel source package.
# Usage: scripts/fetch-valve-source.sh /path/to/trusted-steamos-keyring.gpg [destination]
#
# The keyring must already contain Valve's official package signing key and
# must have been obtained/authenticated independently from Valve.

KEYRING="${1:?usage: $0 TRUSTED_KEYRING.gpg [DESTINATION]}"
DEST="${2:-$PWD/valve-source}"
BASE="https://steamdeck-packages.steamos.cloud/archlinux-mirror/sources/jupiter-3.10"
FILE="linux-neptune-73-7.3.1.valve3-1.src.tar.gz"

[[ -s "$KEYRING" ]] || { echo "error: trusted keyring missing: $KEYRING" >&2; exit 1; }
command -v curl >/dev/null || { echo "error: curl is required" >&2; exit 1; }
command -v gpgv >/dev/null || { echo "error: gpgv is required" >&2; exit 1; }
command -v sha256sum >/dev/null || { echo "error: sha256sum is required" >&2; exit 1; }
command -v tar >/dev/null || { echo "error: tar is required" >&2; exit 1; }

mkdir -p "$DEST"
DEST="$(cd "$DEST" && pwd)"
cd "$DEST"

for suffix in "$FILE" "$FILE.sig"; do
  if [[ ! -s "$suffix" ]]; then
    curl --fail --location --retry 5 --retry-all-errors \
      --output "$suffix.part" "$BASE/$suffix"
    mv "$suffix.part" "$suffix"
  fi
done

echo "Verifying detached Valve package signature..."
gpgv --keyring "$KEYRING" "$FILE.sig" "$FILE"

echo "Recording source archive SHA-256..."
sha256sum "$FILE" | tee "$FILE.sha256"

if [[ ! -d extracted ]] || [[ -z "$(find extracted -mindepth 1 -maxdepth 1 -print -quit)" ]]; then
  mkdir -p extracted
  tar --extract --gzip --file "$FILE" --directory extracted
  echo "Archive extracted under: $DEST/extracted"
else
  echo "Non-empty extracted directory found; not extracting over it."
fi

echo
echo "Next: inspect the extracted PKGBUILD and embedded bare Git repository."
echo "Record the package's source revision and shipped base config before building."
