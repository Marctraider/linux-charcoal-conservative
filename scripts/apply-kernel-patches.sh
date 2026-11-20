#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
KERNEL_TREE="${1:?usage: $0 KERNEL_TREE}"
KERNEL_TREE="$(realpath "$KERNEL_TREE")"
EXPECTED_SOURCE="6fbfd992c8fee6877006b53cca0110bc9586fc00"
ZEN2_PATCH="$ROOT/patches/zen2-cpu-optimizations.patch"
POLLY_PATCH="$ROOT/patches/clang-polly.patch"
CPU_PATCH="$ROOT/patches/vangogh_allow_higher_cpu_freq.patch"

if [[ -d "$KERNEL_TREE/.git" ]]; then
  pinned="$(git -C "$KERNEL_TREE" rev-parse '7.3.1-valve3^{commit}' 2>/dev/null || true)"
  [[ "$pinned" == "$EXPECTED_SOURCE" ]] || {
    echo "error: source tag 7.3.1-valve3 does not resolve to the pinned commit" >&2
    exit 1
  }
  git -C "$KERNEL_TREE" merge-base --is-ancestor "$EXPECTED_SOURCE" HEAD || {
    echo "error: kernel tree is not based on the pinned Valve source commit" >&2
    exit 1
  }
fi

[[ -f "$KERNEL_TREE/Makefile" && -f "$KERNEL_TREE/init/Kconfig" ]] || {
  echo "error: not a Linux source tree: $KERNEL_TREE" >&2
  exit 1
}
CPU_FILE="$KERNEL_TREE/drivers/gpu/drm/amd/pm/swsmu/smu11/vangogh_ppt.c"
[[ -f "$CPU_FILE" ]] || { echo "error: Van Gogh SMU source file missing" >&2; exit 1; }

need_zen2=false
if ! grep -Fq 'config MZEN2' "$KERNEL_TREE/arch/x86/Kconfig.cpu"; then
  [[ -s "$ZEN2_PATCH" ]] || { echo "error: Zen 2 CPU tuning patch missing" >&2; exit 1; }
  patch --directory "$KERNEL_TREE" --strip=1 --dry-run < "$ZEN2_PATCH"
  need_zen2=true
fi

need_polly=false
if ! grep -Fq 'config POLLY_CLANG' "$KERNEL_TREE/init/Kconfig"; then
  [[ -s "$POLLY_PATCH" ]] || { echo "error: Polly patch missing" >&2; exit 1; }
  patch --directory "$KERNEL_TREE" --strip=1 --dry-run < "$POLLY_PATCH"
  need_polly=true
fi

need_cpu=false
if ! grep -Fq 'smu->cpu_default_soft_max_freq = 4200;' "$CPU_FILE"; then
  grep -Fq 'smu->cpu_default_soft_max_freq = 3500;' "$CPU_FILE" || {
    echo "error: expected Valve 3.5 GHz assignment not found; source mismatch." >&2
    exit 1
  }
  [[ -s "$CPU_PATCH" ]] || { echo "error: 4.2 GHz patch missing" >&2; exit 1; }
  patch --directory "$KERNEL_TREE" --strip=1 --dry-run < "$CPU_PATCH"
  need_cpu=true
fi

# All missing patches have passed a dry-run before any source file is changed.
if [[ "$need_zen2" == true ]]; then
  patch --directory "$KERNEL_TREE" --strip=1 < "$ZEN2_PATCH"
  grep -Fq 'config MZEN2' "$KERNEL_TREE/arch/x86/Kconfig.cpu"
  echo "Applied Zen 2 CPU tuning Kconfig/Kbuild patch."
else
  echo "Zen 2 CPU tuning support already present."
fi

if [[ "$need_polly" == true ]]; then
  patch --directory "$KERNEL_TREE" --strip=1 < "$POLLY_PATCH"
  grep -Fq 'config POLLY_CLANG' "$KERNEL_TREE/init/Kconfig"
  echo "Applied Charcoal Clang Polly Kconfig/Kbuild support."
else
  echo "Clang Polly Kconfig support already present."
fi

if [[ "$need_cpu" == true ]]; then
  patch --directory "$KERNEL_TREE" --strip=1 < "$CPU_PATCH"
  grep -Fq 'smu->cpu_default_soft_max_freq = 4200;' "$CPU_FILE"
  echo "Applied 4.2 GHz CPU soft maximum patch."
else
  echo "4.2 GHz CPU ceiling patch already applied."
fi

grep -Fq -- '-march=znver2' "$KERNEL_TREE/arch/x86/Makefile" || {
  echo "error: Zen 2 Kbuild compiler flag is missing" >&2
  exit 1
}
grep -Fq 'LLVMPolly.so' "$KERNEL_TREE/Makefile" || {
  echo "error: Clang Polly Kbuild plugin flag is missing" >&2
  exit 1
}
