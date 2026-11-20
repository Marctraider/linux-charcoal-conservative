# Implementation status

## Baseline and source pin

- SteamOS 3.10 is the intended target release; its Preview notes are available from Valve.
- Linux 7.3 is the intended kernel series.
- Source pin identified from the official `jupiter-main` package index: Valve `linux-neptune-73` 7.3.1 `valve3-1`, kernel tag `7.3.1-valve3`, resolved commit `6fbfd992c8fee6877006b53cca0110bc9586fc00`. The Valve base config and Neptune fragment are vendored in `config-valve-base` and `config-valve-neptune`. The 3.2 GiB source package archive has not yet been downloaded/signature-verified, and the full kernel tree has not been checked out or built. See `docs/SOURCE_PIN.md`.
- The Charcoal configuration fragments in this repository are copied from V10lator/linux-charcoal. Their contents must be reconciled against the pinned 7.3 tree with `merge_config.sh` and `olddefconfig`.

## Driver policy

The four requested external drivers are not to be fetched, built, packaged, or advertised as provided:
- ryzen_smu
- xone
- xpadneo
- xpad-noone

The Charcoal config fragment's explicit disabling of the in-tree `JOYSTICK_XPAD` and `JOYSTICK_XBOX_GIP` drivers was removed, because those are Linux in-tree drivers and the external replacements are excluded. The Neptune fragment's in-tree `JOYSTICK_XBOX_GIP=m` setting is retained.

## Requested kernel changes

- Zen 2 / Van Gogh: Charcoal selects `CONFIG_MZEN2=y`; `patches/zen2-cpu-optimizations.patch` adds the Kconfig/Kbuild support and `-march=znver2` target. This is deliberately Deck-specific. See `docs/CPU_TUNING.md`.
- CPU mitigations: `CONFIG_CPU_MITIGATIONS=n` is retained from Charcoal.
- Clang LTO/Polly: `CONFIG_LTO_CLANG_FULL=y` and `CONFIG_POLLY_CLANG=y` are retained from Charcoal. `patches/clang-polly.patch` ports the Kconfig and Kbuild support used by Charcoal; a Polly-enabled LLVM toolchain is required.
- Van Gogh CPU ceiling: `patches/vangogh_allow_higher_cpu_freq.patch` changes the exact 3500 MHz assignment found in the pinned Valve `vangogh_ppt.c` to 4200 MHz. `scripts/apply-kernel-patches.sh` checks the source tag ancestry and patch context before applying. It has not yet been applied to a full local tree or compiled.
- AMD per-core EPP boost: requested patch series is an RFC, not an established upstream Linux 7.3 feature. `scripts/apply-amd-epp-rfc.sh` fetches and applies the three functional RFC messages to a clean exact Valve tag checkout; the documentation-only fourth message is best-effort. The RFC base commit diverges from the Valve tag, so applicability is not assumed. No EPP patch has yet been applied or compiled.
- LAVD: `CONFIG_SCHED_CLASS_EXT=y` enables the kernel sched_ext interface. The SteamOS `scx-scheds` 1.1.3.linux.steamos.2-2 PKGBUILD is now vendored at `packages/scx-scheds/PKGBUILD`, pinned to source commit `09f66735e5b52023a44001d019ca19204cb5760b`; it builds only `scx_lavd` and installs the systemd unit/defaults. The package has not yet been built against this kernel or enabled on Deck.
- Performance mode: SteamOS Manager exposes `steamosctl set-performance-profile performance` as the supported runtime control. Persistence and Steam Client restore ordering are not yet verified, so no boot-time service has been added. See `docs/PERFORMANCE_PROFILE.md`.

## Not yet done / not yet validated

- Download and verify the Valve source package archive with `bash scripts/fetch-valve-source.sh /path/to/trusted-steamos-keyring.gpg` if the signed package recipe artifact is needed. Then check out the pinned kernel tree with `scripts/checkout-valve-kernel.sh`; the helper verifies the resolved commit SHA. The current official package index is `jupiter-main`.
- Reconcile all four config layers against the pinned kernel and review every unknown/removed Kconfig symbol. `scripts/merge-config.sh` now follows Valve's layering order (Valve base -> Valve Neptune -> Charcoal Neptune -> Charcoal). `config-charcoal` explicitly enables `CONFIG_MZEN2=y`, `CONFIG_SCHED_CLASS_EXT=y`, `CONFIG_LTO_CLANG_FULL=y`, `CONFIG_POLLY_CLANG=y`, and `CONFIG_JOYSTICK_XPAD=m`.
- Confirm the Zen 2, Clang Polly, and 4.2 GHz patches apply cleanly, then confirm all retained patches compile. `scripts/build-kernel.sh` orchestrates the EPP import, these patches, config merge, and LLVM build; it does not install the kernel.
- Attempt the guarded EPP RFC series import, resolve any target-tree conflicts manually, then compile and hardware-test the result.
- Build `packages/scx-scheds/PKGBUILD` and validate `scx_lavd` against the pinned kernel/BTF runtime. Retrieval helper: `bash scripts/fetch-scx-scheds.sh /path/to/trusted-steamos-keyring.gpg`. Keep the systemd service disabled until boot, suspend/resume, and recovery testing passes. See `docs/SCX_LAVD.md`.
- Build and inspect the root `PKGBUILD` output; validate the drop-in `linux-neptune-73` upgrade, initramfs preset generation, boot entry handling, and recovery before any installation. Implement safe package replacement/rollback only after these tests.
- Build kernel and headers with the selected Clang/LLVM toolchain.
- Test boot, suspend/resume, Wi-Fi, Bluetooth, audio, touchscreen, controls, storage, GPU, fan/thermal behavior, performance profiles, and recovery/rollback on actual Steam Deck hardware.

This status file is intentionally explicit: Valve and Charcoal config layers, the requested Zen 2, frequency, and Polly patches, EPP import tooling, kernel/LAVD package recipes, and build scripts are present. The kernel tree has not been checked out or compiled here, and no package has been built, installed, or boot-tested.
