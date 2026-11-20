# Implementation status

## Baseline and source pin

- SteamOS 3.10 is the intended target release; its Preview notes are available from Valve.
- Linux 7.3 is the intended kernel series.
- The exact Valve `linux-integration` revision used by the SteamOS 3.10 package still needs to be pinned from Valve's package source. Do not substitute an arbitrary upstream 7.3 stable tag: Valve's tree/configuration is the compatibility baseline.
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
- Van Gogh CPU ceiling: `patches/vangogh_allow_higher_cpu_freq.patch` is copied from Charcoal and changes the SMU default soft maximum from 3500 to 4200 MHz. It must be checked/rebased against the exact Valve 7.3 source before use.
- AMD per-core EPP boost: requested patch series is an RFC, not an established upstream Linux 7.3 feature. The July 2026 series targets AMD P-State active mode on MSR-based CPPC systems and exposes `epp_boost`; it must be reviewed/ported as a distinct patch and tested on Van Gogh. Do not claim it is upstream.
- LAVD: `CONFIG_SCHED_CLASS_EXT=y` enables the kernel sched_ext interface. It does not itself install or activate LAVD. LAVD is a sched_ext BPF scheduler/userspace component and must be packaged separately, version-pinned, and integrated with the Deck's service/session management.
- Performance mode: installer/service integration still needs to be implemented and tested. Do not force a performance profile until the supported SteamOS profile interface and restore behavior are confirmed.

## Not yet done / not yet validated

- Pin exact Valve SteamOS 3.10 source revision and base config.
- Reconcile both config fragments against the pinned kernel and review every unknown/removed Kconfig symbol.
- Confirm all retained patches apply cleanly and compile.
- Port and validate EPP boost patch series.
- Pin and package a compatible scx_lavd release and userspace dependencies.
- Implement safe package replacement/rollback and initramfs regeneration.
- Build kernel and headers with the selected Clang/LLVM toolchain.
- Test boot, suspend/resume, Wi-Fi, Bluetooth, audio, touchscreen, controls, storage, GPU, fan/thermal behavior, performance profiles, and recovery/rollback on actual Steam Deck hardware.

This status file is intentionally explicit: configuration fragments and one requested patch are present, but this is not yet a buildable or tested kernel release.
