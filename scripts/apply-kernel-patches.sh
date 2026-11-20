#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
KERNEL_TREE="${1:?usage: $0 KERNEL_TREE}"

KERNEL_TREE="$(realpath "$KERNEL_TREE")"
PATCH_FILE="$ROOT/patches/vangogh_allow_higher_cpu_freq.patch"

[[ -f "$KERNEL_TREE/drivers/gpu/drm/amd/pm/swsmu/smu11/vangogh_ppt.c" ]] || {
  echo "error: not a Linux source tree: $KERNEL_TREE" >&2
  exit 1
}
[[ -s "$PATCH_FILE" ]] || { echo "error: patch missing: $PATCH_FILE" >&2; exit 1; }

if grep -Fq 'smu->cpu_default_soft_max_freq = 4200;' \
  "$KERNEL_TREE/drivers/gpu/drm/amd/pm/swsmu/smu11/vangogh_ppt.c"; then
  echo "4.2 GHz ceiling patch already applied."
  exit 0
fi

grep -Fq 'smu->cpu_default_soft_max_freq = 3500;' \
  "$KERNEL_TREE/drivers/gpu/drm/amd/pm/swsmu/smu11/vangogh_ppt.c" || {
  echo "error: expected Valve 3.5 GHz assignment not found; source mismatch." >&2
  exit 1
}

patch --directory "$KERNEL_TREE" --strip=1 --dry-run < "$PATCH_FILE"
patch --directory "$KERNEL_TREE" --strip=1 < "$PATCH_FILE"

grep -Fq 'smu->cpu_default_soft_max_freq = 4200;' \
  "$KERNEL_TREE/drivers/gpu/drm/amd/pm/swsmu/smu11/vangogh_ppt.c"
echo "Applied 4.2 GHz CPU soft maximum patch."
