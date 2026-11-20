#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
KERNEL_TREE="${1:?usage: $0 KERNEL_TREE BASE_CONFIG}"
BASE_CONFIG="${2:?usage: $0 KERNEL_TREE BASE_CONFIG}"

KERNEL_TREE="$(realpath "$KERNEL_TREE")"
BASE_CONFIG="$(realpath "$BASE_CONFIG")"

[[ -d "$KERNEL_TREE/scripts/kconfig" ]] || {
  echo "error: $KERNEL_TREE is not a configured Linux source tree" >&2
  exit 1
}
[[ -x "$KERNEL_TREE/scripts/kconfig/merge_config.sh" ]] || {
  echo "error: merge_config.sh is missing or not executable" >&2
  exit 1
}
[[ -f "$BASE_CONFIG" ]] || {
  echo "error: base config not found: $BASE_CONFIG" >&2
  exit 1
}

cp "$BASE_CONFIG" "$KERNEL_TREE/.config"

# Neptune is applied first; Charcoal is last so its requested config choices
# take precedence. Both are reconciled against this exact kernel's Kconfig.
"$KERNEL_TREE/scripts/kconfig/merge_config.sh" -m -O "$KERNEL_TREE" \
  "$KERNEL_TREE/.config" \
  "$ROOT/config-neptune" \
  "$ROOT/config-charcoal"

make -C "$KERNEL_TREE" LLVM=1 olddefconfig

CONFIG="$KERNEL_TREE/.config"
require_value() {
  local symbol="$1" expected="$2" actual
  actual="$(sed -n "s/^CONFIG_${symbol}=//p" "$CONFIG" | tail -n1)"
  if [[ "$actual" != "$expected" ]]; then
    echo "error: CONFIG_${symbol} expected '$expected', got '${actual:-unset}'" >&2
    exit 1
  fi
}

require_enabled() {
  local symbol="$1" actual
  actual="$(sed -n "s/^CONFIG_${symbol}=//p" "$CONFIG" | tail -n1)"
  if [[ "$actual" != "y" && "$actual" != "m" ]]; then
    echo "error: CONFIG_${symbol} must be built-in or modular, got '${actual:-unset}'" >&2
    exit 1
  fi
}

require_value CPU_MITIGATIONS n
require_value SCHED_CLASS_EXT y
require_enabled JOYSTICK_XPAD
require_enabled JOYSTICK_XBOX_GIP

echo "Config merge complete: $CONFIG"
echo "Verified: CPU mitigations disabled; sched_ext enabled; in-tree XPAD and Xbox GIP retained."
echo "Review the full olddefconfig diff before building; this script does not validate hardware support."
