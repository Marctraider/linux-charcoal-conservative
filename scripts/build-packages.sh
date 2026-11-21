#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
command -v makepkg >/dev/null || { echo "error: makepkg is required" >&2; exit 1; }
[[ "$EUID" -ne 0 ]] || { echo "error: run makepkg as an unprivileged build user" >&2; exit 1; }

cd "$ROOT"
# SRCDEST is persistent across CI runs. Drop the stale local-file cache entry:
# makepkg otherwise reuses it instead of reading patches/clang-polly.patch.
rm -f "$ROOT/.cache/makepkg-sources/clang-polly.patch"
makepkg --syncdeps --noconfirm

cd "$ROOT/packages/scx-scheds"
makepkg --syncdeps --noconfirm

echo
echo "Built packages:"
find "$ROOT" -maxdepth 3 -type f \( -name 'linux-neptune-73-*.pkg.tar.*' -o -name 'scx-scheds-*.pkg.tar.*' \) -print
echo "No packages were installed."
