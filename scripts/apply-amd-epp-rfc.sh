#!/usr/bin/env bash
set -euo pipefail

# Import David Vernet's four-patch AMD per-core EPP boost RFC.
# The original email patches are vendored and identity-checked so builds do
# not depend on public-inbox mirrors being reachable at build time.
# Source archive: https://github.com/sandikata/ROKO__/tree/c45e1d966c9bbc88bb02d1b22f05a94325746036/sys-kernel/xanmod-kernel/files
# Original thread: https://lore.kernel.org/lkml/20260728073150.54964-1-void@manifault.com/
# Usage: scripts/apply-amd-epp-rfc.sh KERNEL_TREE

TREE="${1:?usage: $0 KERNEL_TREE}"
TREE="$(realpath "$TREE")"
TAG="7.3.1-valve3"
PATCH_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../patches/amd-pstate-epp-rfc" && pwd)"

command -v git >/dev/null || { echo "error: git is required" >&2; exit 1; }
[[ -d "$TREE/.git" ]] || { echo "error: expected a Git checkout: $TREE" >&2; exit 1; }
[[ "$(git -C "$TREE" describe --exact-match --tags HEAD 2>/dev/null || true)" == "$TAG" ]] || {
  echo "error: HEAD must be the untouched $TAG tag before applying the RFC." >&2
  exit 1
}
[[ -z "$(git -C "$TREE" status --porcelain)" ]] || {
  echo "error: kernel tree must be clean before applying the RFC." >&2
  exit 1
}

for n in 1 2 3 4; do
  file="$PATCH_DIR/$n.patch"
  [[ -s "$file" ]] || { echo "error: missing vendored RFC patch $n/4" >&2; exit 1; }
  grep -Fq "Subject: [RFC PATCH $n/4]" "$file" || {
    echo "error: unexpected subject in RFC patch $n/4" >&2; exit 1;
  }
  grep -Fq "Message-ID: <20260728073150.54964-$((n + 1))-void@manifault.com>" "$file" || {
    echo "error: Message-ID mismatch in RFC patch $n/4" >&2; exit 1;
  }
done

# Valve's pinned tag already contains RFC patch 1's kernel-doc additions.
# Confirm all five fields are documented before omitting that redundant patch.
HEADER="$TREE/drivers/cpufreq/amd-pstate.h"
for marker in \
  '@val: Raw 64-bit value for atomic access via READ_ONCE()/WRITE_ONCE()' \
  '@raw_epp: Whether the last EPP write was a raw numeric value rather than a' \
  '@current_profile: Currently selected platform profile option' \
  '@ppdev: Device registered with the platform profile handler' \
  '@profile_name: Name under which @ppdev is registered'; do
  grep -Fq "$marker" "$HEADER" || {
    echo "error: patch 1 is not already represented in Valve's header: $marker" >&2
    exit 1
  }
done

git -C "$TREE" config user.name "Kernel Patch Import"
git -C "$TREE" config user.email "kernel-patch-import@localhost"
if ! git -C "$TREE" am --keep-cr "$PATCH_DIR/2.patch" \
     "$PATCH_DIR/3.patch" "$PATCH_DIR/4.patch"; then
  git -C "$TREE" am --abort || true
  echo "error: AMD EPP RFC patches 2-4 did not apply; tree restored to the tag." >&2
  exit 1
fi

echo "AMD per-core EPP RFC patches 2-4 imported on top of $TAG; patch 1 was already present in Valve's tag."
echo "Review the four commits, compile, and hardware-test before enabling epp_boost."
