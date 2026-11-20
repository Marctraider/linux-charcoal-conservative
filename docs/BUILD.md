# Build workflow

This repository now has a reproducible source/config/patch/build path. It does not install the kernel or alter the Deck's boot configuration.

## Host requirements

Use a Linux build host with several hundred GiB of free disk space for the large kernel source and build tree. Install:

- Git, GNU patch, curl, make, bc, bison, flex, cpio, gettext, perl, python, tar, xz, zstd
- Clang/LLVM, LLD, llvm-ar, llvm-nm, llvm-objcopy, pahole, libelf, OpenSSL headers
- A Clang build that includes Polly and provides the `LLVMPolly.so` plugin
- Rust toolchain and bindgen components required by the Valve kernel's Kconfig/build

The exact dependency list should be reconciled with the pinned Valve PKGBUILD before packaging.

## Checkout and build

From the repository root:

```bash
bash scripts/checkout-valve-kernel.sh /path/to/linux-neptune-73
bash scripts/build-kernel.sh /path/to/linux-neptune-73
```

The checkout helper verifies tag `7.3.1-valve3` resolves to commit `6fbfd992c8fee6877006b53cca0110bc9586fc00` and writes its commit record outside the Git tree so the initial checkout remains clean.

The build helper then:

1. Imports the requested AMD per-core EPP RFC driver series. If its functional patches do not apply cleanly, it stops and restores the kernel tree to the pinned tag.
2. Applies Charcoal's Polly Kconfig/Kbuild support and the requested Van Gogh 4.2 GHz ceiling patch, after dry-running both against the source tree.
3. Merges Valve base -> Valve Neptune -> Charcoal Neptune -> Charcoal config, then runs `olddefconfig`.
4. Verifies CPU mitigations remain disabled, sched_ext and AMD P-State remain enabled, and full Clang LTO, Polly, BPF, and BTF support survived Kconfig resolution.
5. Builds the kernel and bpftool BTF header with LLVM.

The build stops rather than silently dropping a requested config option. If the RFC cannot be applied to this diverged Valve source, that conflict must be resolved and reviewed manually; do not force-apply it.

## Output and limitations

The script runs `make all` and builds the bpftool BTF header. It does not create Arch packages, install modules, replace Valve's kernel, regenerate the Deck initramfs, change the bootloader, or set the performance profile. Those steps require a separate package/install design with a verified fallback kernel and rollback procedure.

A successful compile is not proof of Steam Deck runtime stability. Boot, controller, touchscreen, audio, Wi-Fi, Bluetooth, GPU, thermal, suspend/resume, and recovery tests are still required on hardware.
