Trigger the full GitHub Actions kernel package build.
Retry full package build after fixing local makepkg source paths and incrementing kernel package release.

Retry kernel build with lore.landau.one mirror fallback for the AMD EPP RFC patch series.

Retry with explicit HTTP user agent for lore mirror access.

Retry after correcting the EPP importer checksum and adding persistent source-download and ccache caches.

Retry kernel build using locally vendored, Message-ID-verified AMD EPP RFC patches; no network dependency during prepare().

Retry after detecting RFC patch 1 is already present in Valve source.

Retry with three-way application for RFC patches 2-4.
Run full kernel, headers, and LAVD package build after successful AMD EPP RFC preflight on Valve 7.3.1-valve3.
Run full kernel, headers, and LAVD package build with the minimal direct AMD Zen 2 compiler target.
Run full kernel, headers, and LAVD package build with the minimal direct AMD Zen 2 compiler target.
checksum-fix-2026-11-21
Retry build with Polly patch ported to Valve 7.3.1 source context.
Re-run after correcting Polly unified-diff hunk length and checksum.
Rebuild after correcting clang-polly.patch SHA-256.
Clear the stale cached zero-byte clang-polly.patch before makepkg source validation.
Start kernel build after verified clang-polly.patch checksum correction (2026-11-21).
