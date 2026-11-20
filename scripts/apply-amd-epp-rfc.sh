#!/usr/bin/env bash
set -euo pipefail

# Fetch and apply David Vernet's complete four-patch RFC series in order.
# The series is RFC, not upstream-merged. Applying it is an explicit,
# reviewable source-tree operation; this helper does not claim validation.
# Usage: scripts/apply-amd-epp-rfc.sh KERNEL_TREE

TREE="${1:?usage: $0 KERNEL_TREE}"
TREE="$(realpath "$TREE")"
TAG="7.3.1-valve3"
MID="20260728073150.54964-"
BASES=("https://lore.kernel.org/linux-pm" "https://lore.kernel.org/linux-kernel" "https://lore.kernel.org/lkml")

command -v curl >/dev/null || { echo "error: curl is required" >&2; exit 1; }
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

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

for n in 2 3 4; do
  patch_no=$((n - 1))
  file="$TMP/$patch_no.patch"
  fetched=false
  for base in "${BASES[@]}"; do
    url="$base/$MID$n-void@manifault.com/raw"
    if curl --fail --location --retry 2 --retry-all-errors --output "$file.part" "$url"; then
      mv "$file.part" "$file"
      fetched=true
      break
    fi
  done
  [[ "$fetched" == true ]] || {
    echo "error: unable to retrieve RFC patch $patch_no/4 from lore.kernel.org" >&2
    exit 1
  }
  grep -Fq "Subject: [RFC PATCH $patch_no/4]" "$file" || {
    echo "error: unexpected message returned for RFC patch $patch_no/4" >&2
    exit 1
  }
  grep -Fq "Message-ID: <$MID$n-void@manifault.com>" "$file" || {
    echo "error: Message-ID mismatch for RFC patch $patch_no/4" >&2
    exit 1
  }
done

# The final patch only documents the parameter. Fetch it best-effort so a
# documentation archive outage cannot block the functional driver series.
DOC_FILE="$TMP/4.patch"
DOC_FETCHED=false
for base in "${BASES[@]}"; do
  url="$base/$MID5-void@manifault.com/raw"
  if curl --fail --location --retry 2 --retry-all-errors --output "$DOC_FILE.part" "$url"; then
    mv "$DOC_FILE.part" "$DOC_FILE"
    DOC_FETCHED=true
    break
  fi
done
if [[ "$DOC_FETCHED" == true ]]; then
  if ! grep -Fq "Subject: [RFC PATCH 4/4]" "$DOC_FILE" ||
     ! grep -Fq "Message-ID: <$MID5-void@manifault.com>" "$DOC_FILE"; then
    DOC_FETCHED=false
    echo "warning: documentation RFC patch 4/4 failed identity checks" >&2
  fi
else
  echo "warning: unable to retrieve documentation-only RFC patch 4/4" >&2
fi

# Patches 1-3 contain the driver changes and are an atomic required unit.
# Patch 4 is documentation-only; attempt it separately so a doc-context
# conflict does not discard the functional driver changes.
if ! git -C "$TREE" -c user.name="Kernel Patch Import" \
     -c user.email="kernel-patch-import@localhost" \
     am --keep-cr "$TMP/1.patch" "$TMP/2.patch" "$TMP/3.patch"; then
  git -C "$TREE" am --abort || true
  echo "error: functional EPP RFC patches did not apply; tree restored to the tag." >&2
  exit 1
fi

if [[ "$DOC_FETCHED" == true ]]; then
  if git -C "$TREE" -c user.name="Kernel Patch Import" \
       -c user.email="kernel-patch-import@localhost" \
       am --keep-cr "$DOC_FILE"; then
    echo "Applied EPP documentation patch."
  else
    git -C "$TREE" am --abort || true
    echo "warning: driver patches applied, but documentation patch 4/4 did not apply." >&2
    echo "Add the documentation manually after reviewing the target amd-pstate guide." >&2
  fi
else
  echo "Driver patches applied; documentation patch 4/4 was skipped."
fi

echo "EPP driver series imported on top of $TAG. Review commits, compile, and hardware-test."
