# Charcoal Conservative — SteamOS 3.10 / Linux 7.3

A Steam Deck kernel project based on Valve's SteamOS/Neptune kernel configuration and V10lator's Charcoal configuration.

## Requested scope

- Target SteamOS 3.10 / Linux 7.3 (exact Valve source revision must be pinned before building).
- Preserve Charcoal's `config-charcoal` and `config-neptune` configuration choices, adapted for the target kernel.
- Exclude only the external drivers `ryzen_smu`, `xone`, `xpadneo`, and `xpad-noone`. Keep in-tree Linux drivers available.
- Zen 2 / AMD Van Gogh compiler target.
- Clang full LTO and Polly. The Charcoal Polly Kconfig/Kbuild support patch is included so `CONFIG_POLLY_CLANG=y` is defined in the Valve tree; the build still requires a Clang toolchain with Polly enabled.
- `CONFIG_CPU_MITIGATIONS=n`.
- Van Gogh SMU CPU soft maximum changed from 3500 MHz to 4200 MHz.
- AMD per-core EPP boost, ported from the requested upstream RFC only after checking applicability to the pinned kernel revision.
- `CONFIG_SCHED_CLASS_EXT=y` and LAVD userspace installation/configuration.
- Installer replaces the Valve Neptune kernel package and configures the requested performance profile.

## Current status

The Valve package-source pin is recorded in `docs/SOURCE_PIN.md`: `linux-neptune-73` 7.3.1 `valve3-1` from the official `jupiter-main` source index. The exact kernel tag and commit are pinned (`7.3.1-valve3`, `6fbfd992c8fee6877006b53cca0110bc9586fc00`). Valve's base config and Neptune fragment are vendored. The 3.2 GiB source package archive still needs signature verification if used, and the full kernel tree/config merge/build remain unvalidated. Kernel build, boot test, suspend/resume test, audio/Wi-Fi/input validation, and installer test are still required before calling this build usable.

No third-party driver source is vendored or built. No unrelated scheduler patches are included.

## Configuration workflow

The build starts from the vendored Valve base config and applies Valve Neptune, Charcoal Neptune, and Charcoal layers in order. Run `scripts/merge-config.sh /path/to/linux-source`; it runs the target tree's `olddefconfig` and fails if CPU mitigations are enabled, sched_ext is missing, or either in-tree XPAD driver is disabled. The exact source tag is `7.3.1-valve3`; see `docs/SOURCE_PIN.md`. Review the complete config diff and all unmet/renamed options against Deck hardware before packaging.

## Safety notes

Disabling CPU vulnerability mitigations reduces security. A 4.2 GHz firmware/SMU limit is a requested ceiling, not a guarantee that the APU will sustain that frequency; firmware, voltage, temperature and shared CPU/GPU power limits still apply.
