#!/usr/bin/env bash
set -euo pipefail

# Retrieve the SteamOS sched_ext userspace source candidate.
# Usage: bash scripts/fetch-scx-scheds.sh /path/to/trusted-steamos-keyring.gpg [destination]

KEYRING="${1:?usage: $0 TRUSTED_KEYRING.gpg [DESTINATION]}"
DEST="${2:-$PWD/scx-source}"
BASE="https://steamdeck-packages.steamos.cloud/archlinux-mirror/sources/holo-3.10"
FILE="scx-scheds-1.1.3.linux.steamos.2-2.src.tar.gz"

[[ -s "$KEYRING" ]] || { echo "error: trusted keyring missing: $KEYRING" >&2; exit 1; }
for tool in curl gpgv sha256sum tar; do
  command -v "$tool" >/dev/null || { echo "error: $tool is required" >&2; exit 1; }
done

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

echo "Verifying detached SteamOS package signature..."
gpgv --keyring "$KEYRING" "$FILE.sig" "$FILE"
sha256sum "$FILE" | tee "$FILE.sha256"

mkdir -p extracted
tar --extract --gzip --file "$FILE" --directory extracted

echo "Inspect PKGBUILD and verify that the build includes the scx_lavd binary."
echo "Do not enable a service until the binary, dependencies, BTF requirements,"
echo "and runtime behavior have been validated against the target Deck kernel."
