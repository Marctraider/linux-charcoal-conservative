# Valve SteamOS 3.10 kernel source pin

## Selected package snapshot

The SteamOS package-source archive for the `jupiter-3.10` snapshot lists these Valve kernel source packages:

- Package: `linux-neptune-73`
- Upstream kernel version: `7.3.1`
- Valve package release: `valve3-1`
- Source archive: `linux-neptune-73-7.3.1.valve3-1.src.tar.gz`
- Detached signature: `linux-neptune-73-7.3.1.valve3-1.src.tar.gz.sig`
- Snapshot directory: `https://steamdeck-packages.steamos.cloud/archlinux-mirror/sources/jupiter-3.10/`
- Archive listing timestamp: 2026-11-16 23:02 UTC

This is the exact package-source artifact selected for the project baseline. It is a Valve package release pin, not a claim that the entire source archive has already been downloaded, signature-verified, or built in this workspace.

## Retrieval and verification

Download both files from the snapshot directory above. Verify the detached signature using Valve/SteamOS package signing keys obtained through the official SteamOS key distribution process. Do not bypass signature verification.

The source archive is approximately 3.2 GiB. After signature verification, extract it and inspect its PKGBUILD, source URLs, patch list, config files, and commit/revision metadata. Record the SHA-256 of the downloaded archive and the resolved kernel Git commit in the release manifest before building.

## Why this pin

The `jupiter-3.10` package index contains the Valve `linux-neptune-73` 7.3.1 package releases. The selected `valve3-1` revision is the latest listed 7.3.1 release in that snapshot (dated 2026-11-16). The package source is preferred over guessing a commit from an upstream stable branch.

## Build gate

Do not publish a kernel package or run an installer until all of the following are true:

1. The detached signature is valid.
2. The extracted PKGBUILD and source revision are recorded.
3. The exact base config shipped by this package is identified.
4. `config-neptune` and `config-charcoal` are merged into that base config and `olddefconfig` is run with the target tree.
5. The 4.2 GHz and EPP patches are checked against this exact source.
6. The kernel, modules, headers, initramfs integration, and rollback path pass validation.

The repository currently contains reference config fragments and the initial 4.2 GHz patch only. This source pin does not imply that the kernel build or installer is complete.
