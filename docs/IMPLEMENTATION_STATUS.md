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

- CPU mitigations: `CONFIG_CPU_MITIGATIONS=n` is retained from Charcoal.
- Clang LTO/Polly: `CONFIG_LTO_CLANG_FULL=y` and `CONFIG_POLLY_CLANG=y` are retained from Charcoal. `patches/clang-polly.patch` ports the Kconfig and Kbuild support used by Charcoal; a Polly-enabled LLVM toolchain is required.
- Van Gogh CPU ceiling: `patches/vangogh_allow_higher_cpu_freq.patch` changes the exact 3500 MHz assignment found in the pinned Valve `vangogh_ppt.c` to 4200 MHz. `scripts/apply-kernel-patches.sh` checks the source tag ancestry and patch context before applying. It has not yet been applied to a full local tree or compiled.
- AMD per-core EPP boost: requested patch series is an RFC, not an established upstream Linux 7.3 feature. `scripts/apply-amd-epp-rfc.sh` fetches and applies the three functional RFC messages to a clean exact Valve tag checkout; the documentation-only fourth message is best-effort. The RFC base commit diverges from the Valve tag, so applicability is not assumed. No EPP patch has yet been applied or compiled.
- LAVD: `CONFIG_SCHED_CLASS_EXT=y` enables the kernel sched_ext interface. It does not itself install or activate LAVD. LAVD is a sched_ext BPF scheduler/userspace component and must be packaged separately, version-pinned, and integrated with the Deck's service/session management.
- Performance mode: installer/service integration still needs to be implemented and tested. Do not force a performance profile until the supported SteamOS profile interface and restore behavior are confirmed.

## Not yet done / not yet validated

- Download and verify the Valve source package archive with `bash scripts/fetch-valve-source.sh /path/to/trusted-steamos-keyring.gpg` if the signed package recipe artifact is needed. Then check out the pinned kernel tree with `scripts/checkout-valve-kernel.sh`; the helper verifies the resolved commit SHA. The current official package index is `jupiter-main`.
- Reconcile all four config layers against the pinned kernel and review every unknown/removed Kconfig symbol. `scripts/merge-config.sh` now follows Valve's layering order (Valve base -> Valve Neptune -> Charcoal Neptune -> Charcoal). `config-charcoal` explicitly enables `CONFIG_SCHED_CLASS_EXT=y` and `CONFIG_JOYSTICK_XPAD=m`.
- Confirm the Clang Polly support and 4.2 GHz patches apply cleanly, then confirm all retained patches compile. `scripts/build-kernel.sh` orchestrates the EPP import, these patches, config merge, and LLVM build; it does not install the kernel.
- Attempt the guarded EPP RFC series import, resolve any target-tree conflicts manually, then compile and hardware-test the result.
- Validate the SteamOS `scx-scheds` 1.1.3 `linux.steamos.2-2` source candidate against Linux 7.3.1, then package `scx_lavd` and its userspace dependencies. Retrieval helper: `bash scripts/fetch-scx-scheds.sh /path/to/trusted-steamos-keyring.gpg`. See `docs/SCX_LAVD.md`.
- Implement safe package replacement/rollback and initramfs regeneration.
- Build kernel and headers with the selected Clang/LLVM toolchain.
- Test boot, suspend/resume, Wi-Fi, Bluetooth, audio, touchscreen, controls, storage, GPU, fan/thermal behavior, performance profiles, and recovery/rollback on actual Steam Deck hardware.

This status file is intentionally explicit: configuration fragments and one requested patch are present, but this is not yet a buildable or tested kernel release.
