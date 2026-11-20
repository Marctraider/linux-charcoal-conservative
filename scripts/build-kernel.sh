#!/usr/bin/env bash
set -euo pipefail

# Configure and compile the requested kernel. This does not install it.
# Usage: scripts/build-kernel.sh KERNEL_TREE [JOBS]

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
TREE="${1:?usage: $0 KERNEL_TREE [JOBS]}"
JOBS="${2:-$(getconf _NPROCESSORS_ONLN)}"
TREE="$(realpath "$TREE")"
EXPECTED_SOURCE="6fbfd992c8fee6877006b53cca0110bc9586fc00"

for tool in make clang ld.lld; do
  command -v "$tool" >/dev/null || { echo "error: $tool is required" >&2; exit 1; }
done
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
require_value() {
  local symbol="$1" expected="$2" actual
  actual="$(sed -n "s/^CONFIG_${symbol}=//p" "$CONFIG" | tail -n1)"
  [[ "$actual" == "$expected" ]] || {
    echo "error: CONFIG_${symbol} expected '$expected', got '${actual:-unset}'" >&2
    exit 1
  }
}
require_y() {
  require_value "$1" y
}

# Fail rather than silently losing requested Charcoal build options in olddefconfig.
require_value CPU_MITIGATIONS n
require_y SCHED_CLASS_EXT
require_y X86_AMD_PSTATE
require_y MZEN2
require_y LTO_CLANG_FULL
require_y POLLY_CLANG
require_y BPF
require_y BPF_SYSCALL
require_y BPF_JIT
require_y CGROUPS
require_y DEBUG_INFO_BTF

echo "Starting LLVM kernel build with $JOBS jobs..."
(
  cd "$TREE"
  make LLVM=1 -j"$JOBS" all
  make LLVM=1 -C tools/bpf/bpftool vmlinux.h feature-clang-bpf-co-re=1
)

echo "Kernel and BPF tool build completed."
echo "No package was installed and no bootloader or initramfs was modified."
