# AMD per-core EPP boost port

## Reference series

The requested behavior is based on David Vernet's four-patch RFC series posted to linux-pm/linux-kernel on 2026-07-28:

- RFC cover letter: https://lore.landau.one/lkml/0a8a28c6-8af1-4a6e-82d8-166356455aa9%40amd.com/T/
- Patch 3/4 (implementation): https://lists.openwall.net/linux-kernel/2026/07/28/678
- Patch 4/4 (documentation): included in the same RFC thread.

This is an RFC, not an upstream-merged feature. The implementation must be reviewed and ported to the exact Valve Linux 7.3.1 source, not applied blindly by matching line numbers or copied into a different amd-pstate implementation.

## Requested behavior to preserve

- Runtime/module parameter: `amd_pstate.epp_boost=1`, disabled by default unless the project deliberately enables it in its performance profile.
- Only AMD P-State active (EPP) mode on MSR-based CPPC systems (`X86_FEATURE_CPPC`); no effect on shared-memory CPPC, passive mode, or guided mode.
- Sample per-CPU C0 residency (MPERF/TSC) at most once per 10 ms.
- A sample at or above 50% busy temporarily sets only that CPU's CPPC EPP field to performance (EPP 0).
- Keep the temporary boost until 300 ms have elapsed without another busy sample, then restore the most recently cached policy CPPC request.
- Do not change min_perf, max_perf, or desired_perf.
- Correctly register/unregister update-util hooks across CPU online/offline, suspend/resume, policy teardown, and runtime parameter changes.
- Preserve ordering between `cppc_req_cached` updates and MSR writes so restoring the boost cannot reapply stale policy state.

## Porting checklist for the pinned tree

1. Inspect Valve's exact `drivers/cpufreq/amd-pstate.c` and `amd-pstate.h`; compare the RFC's base blob IDs and APIs with the target.
2. Review the RFC's locking, update-util callback context, per-CPU MSR access, CPU hotplug and suspend paths against the target tree.
3. Port the complete dependency series (including cached-request ordering and documentation), adapting APIs as required.
4. Add a Kconfig/module parameter policy and keep the feature disabled by default initially.
5. Build with the target compiler and run sparse/lockdep where available.
6. Hardware-test active mode, EPP policy restoration, CPU hotplug, suspend/resume, dynamic EPP/profile changes, and repeated runtime enable/disable.
7. Benchmark frame-time tails and battery/power draw on Steam Deck; RFC benchmark figures are author-reported results, not a guarantee.

The implementation patch is intentionally not committed yet: the target source archive has not been downloaded, signature-verified, or inspected. This avoids presenting an unrebased RFC diff as a working Linux 7.3.1 patch.
