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
Build authorized after Polly patch hunk-count and checksum fix.
Retry full kernel package build after correcting both Polly patch hunk counts and verifying the updated checksum against Valve 7.3.1-valve3.
Retry kernel build with corrected Polly Kconfig hunk start line and matching SHA-256 checksum.
Run full kernel, headers, and LAVD package build after independently verifying every patch SHA-256 against PKGBUILD.
Build after Kconfig anchor correction, source checksums rechecked.
Rebuild after re-anchoring Van Gogh 4200 MHz patch and verifying its SHA-256 against PKGBUILD.
Build after Kconfig and Pacman keyring validation fixes

Retry after Error 137 during Full LTO vmlinux.o link: serialize only vmlinux_o with -j1, retain -j2 elsewhere, and configure/log 6 GB runner swap.

Retry with corrected vmlinux_a archive target, -j1 vmlinux_o link, -j2 remaining build, and a verified 10 GB runner swap exposed to the build container.
