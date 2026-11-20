# LAVD userspace integration

## Candidate SteamOS package source

The SteamOS `holo-3.10` source index lists:

- Package: `scx-scheds`
- Version/release: `1.1.1.linux.steamos-4`
- Source archive: `scx-scheds-1.1.1.linux.steamos-4.src.tar.gz`
- Detached signature: `scx-scheds-1.1.1.linux.steamos-4.src.tar.gz.sig`
- Snapshot directory: `https://steamdeck-packages.steamos.cloud/archlinux-mirror/sources/holo-3.10/`

This is a candidate SteamOS-packaged userspace source, not yet a validated build dependency for the pinned 7.3.1 kernel. Download and verify the archive using the SteamOS package signing key before inspecting its PKGBUILD and contents.

## Required contents and compatibility checks

Before adopting this package, verify that it builds and installs `scx_lavd` (not merely other sched_ext schedulers), and record its exact source commit and package dependencies. Build and run it against the project's Linux 7.3.1 kernel with:

- `CONFIG_SCHED_CLASS_EXT=y`
- kernel BTF enabled and available at runtime
- the required BPF filesystem and privileges
- matching Clang/LLVM and libbpf build dependencies

The upstream LAVD project describes `scx_lavd` as a sched_ext BPF scheduler with a Rust userspace loader. The kernel sched_ext option alone does not install or activate it.

## Runtime integration policy

The installer must install the verified `scx_lavd` binary and its required runtime libraries, then configure a dedicated systemd service to start it only after the kernel and required BPF/BTF facilities are ready. The service must:

1. Use the explicit `scx_lavd` executable and a documented, conservative argument set.
2. Restart on failure with rate limiting.
3. stop cleanly on shutdown and when the user disables the scheduler.
4. Fall back to the kernel's default scheduler if LAVD cannot load.
5. Never make boot depend on successful LAVD startup.

Do not enable this service by default until it passes boot, gaming, suspend/resume, power-management, and recovery tests on Steam Deck hardware.
