# Zen 2 compiler tuning

The Steam Deck's Van Gogh APU uses AMD Zen 2 CPU cores. The build compiles the kernel's C translation units with Clang's `-march=znver2` via Kbuild's `KCFLAGS` variable. This is a direct compiler target selection; it does not require adding a synthetic `CONFIG_MZEN2` Kconfig option or importing unrelated processor-family definitions.

This makes the resulting kernel specific to Zen 2-class CPUs. Do not install it on older or non-Zen-2 x86 systems. The Van Gogh GPU/SMU tuning is handled separately by `patches/vangogh_allow_higher_cpu_freq.patch`.
