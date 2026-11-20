# Charcoal Conservative — SteamOS 3.10 / Linux 7.3

A Steam Deck kernel project based on Valve's SteamOS/Neptune kernel configuration and V10lator's Charcoal configuration.

## Requested scope

- Target SteamOS 3.10 / Linux 7.3 (exact Valve source revision must be pinned before building).
- Preserve Charcoal's `config-charcoal` and `config-neptune` configuration choices, adapted for the target kernel.
- Exclude only the external drivers `ryzen_smu`, `xone`, `xpadneo`, and `xpad-noone`. Keep in-tree Linux drivers available.
- Zen 2 / AMD Van Gogh compiler target.
- Clang full LTO and Polly where supported by the target source/toolchain.
- `CONFIG_CPU_MITIGATIONS=n`.
- Van Gogh SMU CPU soft maximum changed from 3500 MHz to 4200 MHz.
- AMD per-core EPP boost, ported from the requested upstream RFC only after checking applicability to the pinned kernel revision.
- `CONFIG_SCHED_CLASS_EXT=y` and LAVD userspace installation/configuration.
- Installer replaces the Valve Neptune kernel package and configures the requested performance profile.

## Current status

The Valve package-source pin is recorded in `docs/SOURCE_PIN.md`: `linux-neptune-73` 7.3.1 `valve3-1` from the `jupiter-3.10` snapshot. The source archive still must be downloaded and signature-verified, and its extracted PKGBUILD/base config and resolved kernel commit recorded. Configuration fragments remain reference inputs, not a validated Linux 7.3 `.config`. Kernel build, boot test, suspend/resume test, audio/Wi-Fi/input validation, and installer test are still required before calling this build usable.

No third-party driver source is vendored or built. No unrelated scheduler patches are included.

## Configuration workflow

The build must start from the base config extracted from the pinned SteamOS/Neptune package. Run `scripts/merge-config.sh /path/to/linux-source /path/to/valve-base.config`; it applies `config-neptune` then `config-charcoal`, runs the target tree's `olddefconfig`, and fails if CPU mitigations are enabled, sched_ext is missing, or either in-tree XPAD driver is disabled. Review the complete config diff and all unmet/renamed options against Deck hardware before packaging.

## Safety notes

Disabling CPU vulnerability mitigations reduces security. A 4.2 GHz firmware/SMU limit is a requested ceiling, not a guarantee that the APU will sustain that frequency; firmware, voltage, temperature and shared CPU/GPU power limits still apply.
