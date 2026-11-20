# LAVD userspace integration

## Candidate SteamOS package source

The SteamOS `holo-3.10` source index lists a newer candidate (the latest listed in the snapshot):

- Package: `scx-scheds`
- Version/release: `1.1.3.linux.steamos.2-2`
- Source archive: `scx-scheds-1.1.3.linux.steamos.2-2.src.tar.gz`
- Detached signature: `scx-scheds-1.1.3.linux.steamos.2-2.src.tar.gz.sig`
- SteamOS recipe mirror commit: `d96f9f1998420f7035e92d82f1fcc8eaf10dc950`
- Scheduler source tag: `v1.1.3.linux.steamos.2`
- Resolved scheduler source commit: `09f66735e5b52023a44001d019ca19204cb5760b`
- Scheduler source SHA-256: `75ba7bfb870134009446fc8e286d0d2b99d9102f4c081c246eb87c2363e132b9`
- Snapshot directory: `https://steamdeck-packages.steamos.cloud/archlinux-mirror/sources/holo-3.10/`

This is the exact SteamOS 3.10 package recipe selected for LAVD. The source archive is listed at 265.1 MiB, dated 2026-11-03. The copied PKGBUILD is in `packages/scx-scheds/PKGBUILD`; it builds only `scx_lavd` from the pinned source tag and installs the corresponding service/defaults. Use `bash scripts/fetch-scx-scheds.sh /path/to/trusted-steamos-keyring.gpg` to download, verify its detached signature, and validate the extracted package recipe.

## Required contents and compatibility checks

The SteamOS PKGBUILD's source and tag are now pinned above. Build it with `makepkg -s` from `packages/scx-scheds/`. Before enabling its service, build and run it against the project's Linux 7.3.1 kernel with:

- `CONFIG_SCHED_CLASS_EXT=y`
- kernel BTF enabled and available at runtime
- the required BPF filesystem and privileges
- matching Clang/LLVM and libbpf build dependencies

The upstream LAVD project describes `scx_lavd` as a sched_ext BPF scheduler with a Rust userspace loader. The kernel sched_ext option alone does not install or activate it.

## Runtime integration policy

The package installs `/usr/bin/scx_lavd`, `/etc/default/scx`, and `/usr/lib/systemd/system/scx.service`. Its defaults select `SCX_SCHEDULER=scx_lavd` and `SCX_FLAGS='--pinned-slice-us 500 --dd-max-wait-us 0'`. Its defaults select `SCX_SCHEDULER=scx_lavd` and `SCX_FLAGS='--pinned-slice-us 500 --dd-max-wait-us 0'`. The eventual installer must install the verified binary and runtime libraries, then enable the service only after the kernel and required BPF/BTF facilities are ready. The service must:

1. Use the explicit `scx_lavd` executable and a documented, conservative argument set.
2. Restart on failure with rate limiting.
3. Stop cleanly on shutdown and when the user disables the scheduler.
4. Fall back to the kernel's default scheduler if LAVD cannot load.
5. Never make boot depend on successful LAVD startup.

Do not enable this service by default until it passes boot, gaming, suspend/resume, power-management, and recovery tests on Steam Deck hardware.
