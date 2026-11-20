#!/usr/bin/env bash
set -euo pipefail

# Configure and compile the requested kernel. This does not install it.
# Usage: scripts/build-kernel.sh KERNEL_TREE [JOBS]

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
TREE="${1:?usage: $0 KERNEL_TREE [JOBS]}"
JOBS="${2:-$(getconf _NPROCESSORS_ONLN)}"
TREE="$(realpath "$TREE")"
EXPECTED_SOURCE="6fbfd992c8fee6877006b53cca0110bc9586fc00"

command -v make >/dev/null || { echo "error: make is required" >&2; exit 1; }
command -v clang >/dev/null || { echo "error: clang is required" >&2; exit 1; }
command -v ld.lld >/dev/null || { echo "error: ld.lld is required" >&2; exit 1; }
[[ -d "$TREE/.git" ]] || { echo "error: expected a Git kernel checkout" >&2; exit 1; }
[[ "$(git -C "$TREE" rev-parse '7.3.1-valve3^{commit}')" == "$EXPECTED_SOURCE" ]] || {
  echo "error: kernel tree does not contain the pinned Valve tag" >&2
  exit 1
}
git -C "$TREE" merge-base --is-ancestor "$EXPECTED_SOURCE" HEAD || {
  echo "error: kernel tree is not based on the pinned Valve source commit" >&2
  exit 1
}

# The EPP series is only imported once. A failed import aborts before config/build.
if ! grep -Fq 'module_param_cb(epp_boost' "$TREE/drivers/cpufreq/amd-pstate.c"; then
  "$ROOT/scripts/apply-amd-epp-rfc.sh" "$TREE"
else
  echo "Per-core EPP boost code already present; skipping RFC import."
fi

"$ROOT/scripts/apply-kernel-patches.sh" "$TREE"
"$ROOT/scripts/merge-config.sh" "$TREE"

CONFIG="$TREE/.config"
require_y() {
  local symbol="$1"
  grep -Eq "^CONFIG_${symbol}=y$" "$CONFIG" || {
    echo "error: CONFIG_${symbol}=y was not retained by olddefconfig" >&2
    exit 1
  }
}

require_y CPU_MITIGATIONS=false
