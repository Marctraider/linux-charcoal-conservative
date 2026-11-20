# Valve SteamOS 3.10 kernel source pin

## Selected package snapshot

The SteamOS package-source archive for the `jupiter-main` snapshot lists these Valve kernel source packages:

- Package: `linux-neptune-73`
- Upstream kernel version: `7.3.1`
- Valve package release: `valve3-1`
- Source archive: `linux-neptune-73-7.3.1.valve3-1.src.tar.gz`
- Detached signature: `linux-neptune-73-7.3.1.valve3-1.src.tar.gz.sig`
- Snapshot directory: `https://steamdeck-packages.steamos.cloud/archlinux-mirror/sources/jupiter-main/`
- Archive listing timestamp: 2026-11-17 01:26 UTC

This is the exact Valve package release selected for the project baseline. Its PKGBUILD identifies the kernel source tag as `7.3.1-valve3` and the source URL as `git+https://github.com/evlav/linux-integration.git#tag=7.3.1-valve3`. The GitHub repository is an unofficial mirror used to replace Valve's private source URL in the public package recipe; the tag is the package's intended source revision. The source archive and kernel tree have not been downloaded or built in this workspace.

## Kernel source revision and configs

The Valve `linux-neptune-73/PKGBUILD` in the automatically updated `evlaV/jupiter` mirror records:

- `_tag=7.3.1-valve3`
- Kernel source: `https://github.com/evlav/linux-integration.git#tag=7.3.1-valve3` (public mirror replacing the private Valve URL)
- Valve base config: `config.x86_64`, SHA-256 `ecd8c76eb203493e67ba4052e7bc1fa46f51c91566f102172e7a18d7de2dd5eb`
- Valve Neptune fragment: `config-neptune`, SHA-256 `b91c3ed65067704c8fdb8289d44ed18aa62f98f52c3b6d91fb72bc5b1606ae79`
- PKGBUILD's config layering: copy `config.x86_64`, merge `config-neptune`, then `make olddefconfig`.

The exact config files are vendored as `config-valve-base` and `config-valve-neptune`; their GitHub source blob SHAs are recorded in repository history. The build helper then applies Charcoal's `config-neptune` and `config-charcoal` after Valve's two layers.

Use `bash scripts/checkout-valve-kernel.sh /path/to/linux-neptune-73` to check out the tag and record its resolved commit SHA in `SOURCE_COMMIT`. The mirror is unofficial; compare its source against the Valve package's published tag and do not treat the mirror's repository history as an official Valve signature.

## Retrieval and verification

Use `bash scripts/fetch-valve-source.sh /path/to/trusted-steamos-keyring.gpg` to download the package recipe archive and detached signature, verify the signature using Valve/SteamOS package signing keys obtained and authenticated independently through the official SteamOS key distribution process, record the archive SHA-256, and extract the recipe. Do not bypass signature verification. Then use `scripts/checkout-valve-kernel.sh` to fetch the package's exact source tag.

The source archive is approximately 3.2 GiB. After signature verification, extract it and inspect its PKGBUILD, source URLs, patch list, config files, and commit/revision metadata. Record the SHA-256 of the downloaded archive and the resolved kernel Git commit in the release manifest before building.

## Why this pin

The `jupiter-main` package index contains the Valve `linux-neptune-73` 7.3.1 package releases. The selected `valve3-1` revision is the latest listed 7.3.1 release in the current index (dated 2026-11-17). The package source is preferred over guessing a commit from an upstream stable branch.

## Build gate

Do not publish a kernel package or run an installer until all of the following are true:

1. The detached signature is valid.
2. The extracted PKGBUILD agrees with the vendored recipe, and the resolved `7.3.1-valve3` commit SHA is recorded.
3. The vendored Valve base config and Neptune fragment match the PKGBUILD's SHA-256 values.
4. `config-neptune` and `config-charcoal` are merged into that base config and `olddefconfig` is run with the target tree.
5. The 4.2 GHz and EPP patches are checked against this exact source.
6. The kernel, modules, headers, initramfs integration, and rollback path pass validation.

The repository currently contains reference config fragments and the initial 4.2 GHz patch only. This source pin does not imply that the kernel build or installer is complete.
