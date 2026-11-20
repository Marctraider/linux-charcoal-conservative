#!/usr/bin/env bash
set -euo pipefail

# Validate and import David Vernet's four-patch AMD per-core EPP RFC.
# This uses context-based git apply rather than git am's three-way fallback:
# Valve's pinned tree contains some RFC-1 documentation but its header blob
# is not byte-identical to the RFC-1 result, which makes a three-way merge
# unreliable even where the remaining hunks apply cleanly.
# Usage: scripts/apply-amd-epp-rfc.sh KERNEL_TREE

TREE="${1:?usage: $0 KERNEL_TREE}"
TREE="$(realpath "$TREE")"
TAG="7.3.1-valve3"
BASE_COMMIT="6fbfd992c8fee6877006b53cca0110bc9586fc00"
PATCH_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../patches/amd-pstate-epp-rfc" && pwd)"

command -v git >/dev/null || { echo "error: git is required" >&2; exit 1; }
[[ -d "$TREE/.git" ]] || { echo "error: expected a Git checkout: $TREE" >&2; exit 1; }
[[ "$(git -C "$TREE" describe --exact-match --tags HEAD 2>/dev/null || true)" == "$TAG" ]] || {
  echo "error: HEAD must be the untouched $TAG tag before applying the RFC." >&2
  exit 1
}
[[ "$(git -C "$TREE" rev-parse HEAD)" == "$BASE_COMMIT" ]] || {
  echo "error: kernel tree is not at the pinned Valve commit $BASE_COMMIT." >&2
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

git -C "$TREE" config user.name "Kernel Patch Import"
git -C "$TREE" config user.email "kernel-patch-import@localhost"

# Patch 1 is documentation-only. Skip it only when its actual reverse diff
# applies; marker greps alone are not sufficient to establish equivalence.
if git -C "$TREE" apply --reverse --check "$PATCH_DIR/1.patch" >/dev/null 2>&1; then
  echo "RFC patch 1/4 is already present in the pinned Valve source."
else
  echo "Preflighting RFC patch 1/4..."
  if ! git -C "$TREE" apply --check "$PATCH_DIR/1.patch"; then
    echo "error: RFC patch 1/4 does not apply to the pinned Valve source." >&2
    exit 1
  fi
  git -C "$TREE" apply --index "$PATCH_DIR/1.patch"
  git -C "$TREE" commit -m "cpufreq/amd-pstate: Document missing kernel-doc members"
fi

# Apply each dependent patch only after its complete diff passes a dry run
# against the result of the preceding patch. On any failure, restore the
# exact pinned source so a later build cannot inherit a partial RFC.
for n in 2 3 4; do
  file="$PATCH_DIR/$n.patch"
  subject="$(sed -n 's/^Subject: //p' "$file" | head -n1 | sed -E 's/^\[RFC PATCH [0-9]+\/4\] //')"
  echo "Preflighting RFC patch $n/4: $subject"
  if ! git -C "$TREE" apply --check "$file"; then
    git -C "$TREE" reset --hard "$BASE_COMMIT" >/dev/null
    echo "error: RFC patch $n/4 does not apply cleanly; restored kernel tree to $BASE_COMMIT." >&2
    exit 1
  fi
  git -C "$TREE" apply --index "$file"
  git -C "$TREE" commit -m "$subject" -m "Imported from RFC Message-ID 20260728073150.54964-$((n + 1))-void@manifault.com"
done

grep -Fq 'module_param_cb(epp_boost' "$TREE/drivers/cpufreq/amd-pstate.c"
grep -Fq 'epp_boost_update_util' "$TREE/drivers/cpufreq/amd-pstate.h"
grep -Fq 'Energy performance preference boosting' "$TREE/Documentation/admin-guide/pm/amd-pstate.rst"
[[ -z "$(git -C "$TREE" status --porcelain)" ]] || {
  echo "error: RFC import left an unexpected dirty worktree." >&2
  exit 1
}

echo "PASS: RFC patches 1-4 are represented/applied on the exact Valve $TAG source."
git -C "$TREE" log -4 --oneline
