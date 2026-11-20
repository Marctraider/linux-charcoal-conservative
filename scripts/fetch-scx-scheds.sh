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

if [[ -d extracted ]] && [[ -n "$(find extracted -mindepth 1 -maxdepth 1 -print -quit)" ]]; then
  echo "error: extracted directory is non-empty; move it aside before retrying" >&2
  exit 1
fi
mkdir -p extracted
tar --extract --gzip --file "$FILE" --directory extracted

PKGBUILD_PATH="$(find extracted -type f -name PKGBUILD -print -quit)"
[[ -n "$PKGBUILD_PATH" ]] || {
  echo "error: SteamOS scx source archive contains no PKGBUILD" >&2
  exit 1
}
grep -Fq 'pkgver=1.1.3.linux.steamos.2' "$PKGBUILD_PATH" || {
  echo "error: unexpected scx-scheds package version" >&2
  exit 1
}
grep -Fq "sha256sums=('75ba7bfb870134009446fc8e286d0d2b99d9102f4c081c246eb87c2363e132b9')" "$PKGBUILD_PATH" || {
  echo "error: scx source checksum does not match the pinned SteamOS recipe" >&2
  exit 1
}

echo "Verified SteamOS scx-scheds 1.1.3 PKGBUILD and source checksum."
echo "The package builds scx_lavd and installs its systemd service and defaults."
echo "Do not enable the service until BTF, boot, suspend/resume, and recovery"
echo "behavior have been validated against the target Deck kernel."
