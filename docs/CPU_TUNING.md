# Zen 2 compiler tuning

The Charcoal config selects `CONFIG_MZEN2=y`, but the pinned Valve Linux 7.3.1 tree does not define that Kconfig symbol by default. The repository therefore carries `patches/zen2-cpu-optimizations.patch`, based on Graysky's `more-ISA-levels-and-uarches-for-kernel-6.16+.patch`.

With `CONFIG_MZEN2=y`, the patch selects the AMD Zen 2 compiler target (`-march=znver2`). This is appropriate for the Steam Deck's Van Gogh Zen 2 CPU, but it deliberately makes the resulting kernel target-specific; do not install it on older or non-Zen-2 x86 systems.

The patch also exposes additional processor-family choices and x86-64 ISA levels in Kconfig. Those are not selected by this project; the active choice is only Zen 2. The build helper dry-runs the patch before applying it and the package build fails if `CONFIG_MZEN2=y` is dropped by `olddefconfig`.

Source: https://github.com/graysky2/kernel_compiler_patch/blob/master/more-ISA-levels-and-uarches-for-kernel-6.16+.patch
