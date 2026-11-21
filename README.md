# Charcoal Conservative — SteamOS 3.10 / Linux 7.3

A Steam Deck kernel project based on Valve's SteamOS/Neptune kernel configuration and V10lator's Charcoal configuration.

## Requested scope

- Target SteamOS 3.10 / Linux 7.3; pinned Valve source tag `7.3.1-valve3` at commit `6fbfd992c8fee6877006b53cca0110bc9586fc00`.
- Preserve Charcoal's `config-charcoal` and `config-neptune` configuration choices, adapted for the target kernel.
- Exclude only the external drivers `ryzen_smu`, `xone`, `xpadneo`, and `xpad-noone`. Keep in-tree Linux drivers available.
- Zen 2 / AMD Van Gogh compiler target.
- Clang full LTO and Polly. The Charcoal Polly Kconfig/Kbuild support patch is included so `CONFIG_POLLY_CLANG=y` is defined in the Valve tree; the build still requires a Clang toolchain with Polly enabled.
- `CONFIG_CPU_MITIGATIONS=n`.
- Van Gogh SMU CPU soft maximum changed from 3500 MHz to 4200 MHz.
- AMD per-core EPP boost, ported from the requested upstream RFC only after checking applicability to the pinned kernel revision.
- `CONFIG_SCHED_CLASS_EXT=y` and SteamOS `scx-scheds` 1.1.3.linux.steamos.2-2 userspace package (`packages/scx-scheds/PKGBUILD`), pending runtime validation.
- Installer replaces the Valve Neptune kernel package, installs the LAVD userspace package, and enables `scx_lavd --performance` through the packaged `scx.service`. 

## Current status

The Valve package-source pin is recorded in `docs/SOURCE_PIN.md`: `linux-neptune-73` 7.3.1 `valve3-1` from the official `jupiter-main` source index. The exact kernel tag and commit are pinned (`7.3.1-valve3`, `6fbfd992c8fee6877006b53cca0110bc9586fc00`). Valve's base config and Neptune fragment are vendored. The 3.2 GiB source package archive still needs signature verification if used, and the full kernel tree/config merge/build remain unvalidated. Kernel build, boot test, suspend/resume test, audio/Wi-Fi/input validation, and installer test are still required before calling this build usable.

No third-party driver source is vendored or built. No unrelated scheduler patches are included.

## Kernel packaging

The repository now has a GitHub Actions full-build workflow at `.github/workflows/kernel-build.yml`. It builds the Valve kernel package, headers, and pinned LAVD package in an Arch build environment, validates the package contents/config, and uploads artifacts. The latest package-build workflow is running; static checks pass, but patch application, compilation, package validation, and boot testing are not yet confirmed.


A root `PKGBUILD` based on Valve's Linux Neptune recipe emits a drop-in `linux-neptune-73` package at `pkgrel=3`, preserving Valve's package identity and `pkgbase` so the existing kernel preset naming remains compatible. It is unbuilt and untested; do not install it on a Deck until boot entry, initramfs, and rollback handling are validated. See `docs/BUILD.md`.

## Configuration workflow

The build starts from the vendored Valve base config and applies Valve Neptune, Charcoal Neptune, and Charcoal layers in order. Run `scripts/merge-config.sh /path/to/linux-source`; it runs the target tree's `olddefconfig` and fails if CPU mitigations are enabled, sched_ext is missing, or either in-tree XPAD driver is disabled. The exact source tag is `7.3.1-valve3`; see `docs/SOURCE_PIN.md`. Review the complete config diff and all unmet/renamed options against Deck hardware before packaging.

## Safety notes

Disabling CPU vulnerability mitigations reduces security. A 4.2 GHz firmware/SMU limit is a requested ceiling, not a guarantee that the APU will sustain that frequency; firmware, voltage, temperature and shared CPU/GPU power limits still apply.

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
