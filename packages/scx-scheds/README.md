# LAVD userspace package

This directory contains Valve's SteamOS `scx-scheds` PKGBUILD for version `1.1.3.linux.steamos.2-2`, copied from the `evlaV/holo` mirror commit `d96f9f1998420f7035e92d82f1fcc8eaf10dc950`.

The recipe builds only `scx_lavd` from the upstream sched_ext source tag:

- Source tag: `v1.1.3.linux.steamos.2`
- Resolved source commit: `09f66735e5b52023a44001d019ca19204cb5760b`
- Source SHA-256 recorded by the SteamOS PKGBUILD: `75ba7bfb870134009446fc8e286d0d2b99d9102f4c081c246eb87c2363e132b9`

Build on SteamOS/Arch-compatible tooling:

```bash
cd packages/scx-scheds
makepkg -s
```

The package installs `/usr/bin/scx_lavd`, `/etc/default/scx`, and `scx.service`. Its default environment selects `scx_lavd` with the SteamOS-provided flags. Installing the package does not itself enable the service; service enablement is deliberately left to the eventual installer after Deck boot/recovery validation.

This recipe is pinned to the SteamOS 3.10 source snapshot's 1.1.3 release, not the newer moving `main` package recipe.
