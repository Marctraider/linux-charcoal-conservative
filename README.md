# Charcoal Conservative — SteamOS 3.10 / Linux 7.3

A Steam Deck kernel project based on Valve's SteamOS/Neptune kernel configuration and V10lator's Charcoal configuration.

## Requested scope

- Target SteamOS 3.10 / Linux 7.3; pinned Valve source tag `7.3.1-valve3` at commit `6fbfd992c8fee6877006b53cca0110bc9586fc00`.
- Preserve Charcoal's `config-charcoal` and `config-neptune` configuration choices, adapted for the target kernel.
- Clang compiler target: `-march=znver2` for the Steam Deck's Zen 2 / AMD Van Gogh APU, with explicit `-O2` optimization.
- Clang full LTO and Polly. Built-in kernel code (`=y`) is linked into `vmlinux`, allowing Full LTO to optimize across that link; loadable modules (`=m`) are linked separately and are outside the same whole-kernel LTO pass. The linkage report lists only built-in/module selections that differ from Valve's baseline.
- `CONFIG_CPU_MITIGATIONS=n`.
- Van Gogh SMU CPU soft maximum changed from 3500 MHz to 4200 MHz.
- AMD per-core EPP boost, ported from the requested upstream RFC only after checking applicability to the pinned kernel revision.
- `CONFIG_SCHED_CLASS_EXT=y` and SteamOS `scx-scheds` 1.1.3.linux.steamos.2-2 userspace package (`packages/scx-scheds/PKGBUILD`).
- Installer replaces the Valve Neptune kernel package, installs the LAVD userspace package, and enables `scx_lavd --performance` through the packaged `scx.service`.

## Steam Deck installer

The prepared installer is `install-charcoal.sh`. It preserves Valve's `linux-neptune-73` package identity and installs the kernel, matching headers, and the `scx-scheds` LAVD userspace package together. It configures `scx.service` to run `scx_lavd --performance` and enables that service at boot. If the currently running kernel does not expose sched_ext, service startup is deferred until after reboot into the new kernel. The installer regenerates initramfs, updates GRUB, verifies boot files, attempts cached-package rollback on failure, and does not reboot automatically. `test-runtime.sh` is a separate read-only runtime check for disabled CPU mitigations, AMD per-core EPP boost, the 4200 MHz CPU policy ceiling, and active LAVD `--performance` scheduling.

Release downloads are intentionally not configured until the official package assets and SHA-256 checksums are published. For now, supply all three local package files:

```bash
sudo bash install-charcoal.sh \
  --kernel /path/to/linux-neptune-73.pkg.tar.zst \
  --headers /path/to/linux-neptune-73-headers.pkg.tar.zst \
  --scx /path/to/scx-scheds.pkg.tar.zst
```

Run `sudo bash install-charcoal.sh --check-only` for a Deck and boot-state preflight without installing packages. Add all three package paths with `--check-only` to validate their identities and matching kernel/header metadata too. The installer requires SteamOS 3.10 and an existing Neptune preset, kernel image, and initramfs. After booting the new kernel, run `bash test-runtime.sh` to check the live kernel config, Clang/full-LTO/Polly configuration, package build-recipe metadata (including `-march=znver2`), EPP boost service/parameter, 4200 MHz CPU policy maximum, and LAVD scheduler/mode. The kernel package also carries a generated linkage manifest comparing every changed built-in/module selection (`=y`, `=m`, or disabled) against the stock Valve Neptune configuration; the runtime test prints the Valve state, Charcoal state, and running-kernel state, and checks that the running config matches the Charcoal build. The Zen 2 flag is verified from package build metadata, not independently decoded from the running kernel binary.
