#!/usr/bin/env bash
set -euo pipefail

# Fetch and authenticate the exact Valve SteamOS 3.10 kernel source package.
# Usage: scripts/fetch-valve-source.sh /path/to/trusted-steamos-keyring.gpg [destination]
#
# The keyring must already contain Valve's official package signing key and
# must have been obtained/authenticated independently from Valve.

KEYRING="${1:?usage: $0 TRUSTED_KEYRING.gpg [DESTINATION]}"
DEST="${2:-$PWD/valve-source}"
BASE="https://steamdeck-packages.steamos.cloud/archlinux-mirror/sources/jupiter-main"
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

PKGBUILD_PATH="$(find "$DEST/extracted" -type f -name PKGBUILD -print -quit)"
[[ -n "$PKGBUILD_PATH" ]] || {
  echo "error: source archive contains no PKGBUILD" >&2
  exit 1
}
grep -Fq '_tag=7.3.1-valve3' "$PKGBUILD_PATH" || {
  echo "error: PKGBUILD does not pin the expected 7.3.1-valve3 source tag" >&2
  exit 1
}
BASE_CONFIG="$(find "$DEST/extracted" -type f -name config.x86_64 -print -quit)"
NEPTUNE_CONFIG="$(find "$DEST/extracted" -type f -name config-neptune -print -quit)"
[[ -n "$BASE_CONFIG" && -n "$NEPTUNE_CONFIG" ]] || {
  echo "error: expected Valve base config files are missing" >&2
  exit 1
}
printf '%s  %s\n' \
  "ecd8c76eb203493e67ba4052e7bc1fa46f51c91566f102172e7a18d7de2dd5eb" "$BASE_CONFIG" \
  "b91c3ed65067704c8fdb8289d44ed18aa62f98f52c3b6d91fb72bc5b1606ae79" "$NEPTUNE_CONFIG" \
  | sha256sum --check --status

echo "Verified PKGBUILD tag and Valve config SHA-256 values."

echo
echo "Next: inspect the extracted PKGBUILD and confirm the pinned source URL and tag."
echo "The kernel Git checkout is performed separately by scripts/checkout-valve-kernel.sh."
