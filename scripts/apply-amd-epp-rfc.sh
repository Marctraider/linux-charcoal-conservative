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
  if [[ "$n" == "4" ]]; then
    # The Valve documentation has diverged around the RFC's insertion line.
    # Port the documentation section at a stable section boundary.
    python3 - "$TREE/Documentation/admin-guide/pm/amd-pstate.rst" <<'PY'
import pathlib, sys
p = pathlib.Path(sys.argv[1])
s = p.read_text()
section = """Energy performance preference boosting
======================================
On MSR-based systems running in the ``active mode``, the driver can optionally
bias the energy performance preference of a recently-busy CPU toward
performance while leaving all other CPUs at the policy value.  C0 residency is
sampled at most every 10 ms; while a CPU has been at least 50% busy within the
last 300 ms, the EPP field of its CPPC request is set to ``performance`` (0).
The policy value is restored once 300 ms pass without a busy sample.

This behavior is disabled by default.  It can be enabled with the module
parameter ``amd_pstate.epp_boost=1`` on the kernel command line, or at runtime
by writing ``1`` to ``/sys/module/amd_pstate/parameters/epp_boost``.  The
mechanism only runs while the parameter is enabled and has no overhead when
disabled.  It has no effect in the ``passive`` and ``guided`` modes or on
shared-memory (non-MSR) systems.

"""
anchor = "``amd-pstate`` vs ``acpi-cpufreq``\n======================================"
if "Energy performance preference boosting" not in s:
    assert s.count(anchor) == 1, "unexpected amd-pstate documentation section layout"
    s = s.replace(anchor, section + anchor, 1)
p.write_text(s)
PY
    git -C "$TREE" add Documentation/admin-guide/pm/amd-pstate.rst
    git -C "$TREE" diff --cached --check
    git -C "$TREE" commit -m "$subject" -m "Port RFC documentation to Valve 7.3.1-valve3 layout"
  elif [[ "$n" == "3" ]]; then
    # Valve's amd-pstate.h has a different blob/layout from the RFC base.
    # Apply the amd-pstate.c diff with full context, then port the small
    # header additions using unique, verified anchors from the pinned tree.
    if ! git -C "$TREE" apply --check --include=drivers/cpufreq/amd-pstate.c "$file"; then
      git -C "$TREE" reset --hard "$BASE_COMMIT" >/dev/null
      echo "error: RFC patch 3/4 C changes do not apply; restored pinned source." >&2
      exit 1
    fi
    git -C "$TREE" apply --index --include=drivers/cpufreq/amd-pstate.c "$file"
    python3 - "$TREE/drivers/cpufreq/amd-pstate.h" <<'PY'
import pathlib, sys
p = pathlib.Path(sys.argv[1])
s = p.read_text()
include = "#include <linux/platform_profile.h>\n"
if "#include <linux/sched/cpufreq.h>" not in s:
    assert s.count(include) == 1, "unexpected amd-pstate.h include layout"
    s = s.replace(include, include + "#include <linux/sched/cpufreq.h>\n", 1)
doc_anchor = " * @profile_name: Name under which @ppdev is registered\n"
doc_add = (
    " * @epp_boost_update_util: update-util hook for the per-core EPP boost\n"
    " * @epp_boost_last_sample: last C0-residency sample time (ns; 0 means the\n"
    " *                         next callback only re-baselines the counters)\n"
    " * @epp_boost_last_busy: last time the CPU sampled as busy (ns)\n"
    " * @epp_boost_active: EPP boost currently applied to MSR_AMD_CPPC_REQ\n"
    " * @epp_boost_registered: update-util hook currently registered\n"
)
if "@epp_boost_update_util:" not in s:
    assert s.count(doc_anchor) == 1, "unexpected amd_cpudata kernel-doc layout"
    s = s.replace(doc_anchor, doc_anchor + doc_add, 1)
member_anchor = "\tchar *profile_name;\n"
member_add = (
    "\n\t/* per-core EPP boost (active mode, MSR systems only) */\n"
    "\tstruct update_util_data epp_boost_update_util;\n"
    "\tu64 epp_boost_last_sample;\n"
    "\tu64 epp_boost_last_busy;\n"
    "\tbool epp_boost_active;\n"
    "\tbool epp_boost_registered;\n"
)
if "struct update_util_data epp_boost_update_util;" not in s:
    assert s.count(member_anchor) == 1, "unexpected amd_cpudata member layout"
    s = s.replace(member_anchor, member_anchor + member_add, 1)
p.write_text(s)
PY
    git -C "$TREE" add drivers/cpufreq/amd-pstate.h
    git -C "$TREE" diff --cached --check
    git -C "$TREE" commit -m "$subject" -m "Ported RFC header additions to Valve 7.3.1-valve3 layout"
  else
    if ! git -C "$TREE" apply --check "$file"; then
      git -C "$TREE" reset --hard "$BASE_COMMIT" >/dev/null
      echo "error: RFC patch $n/4 does not apply cleanly; restored kernel tree to $BASE_COMMIT." >&2
      exit 1
    fi
    git -C "$TREE" apply --index "$file"
    git -C "$TREE" commit -m "$subject" -m "Imported from RFC Message-ID 20260728073150.54964-$((n + 1))-void@manifault.com"
  fi
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
