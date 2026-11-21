# Maintainer: John Schoenick <johns@valvesoftware.com>
# Maintainer: Jan Alexander Steffens (heftig) <heftig@archlinux.org>

pkgbase=linux-neptune-73
_tag=7.3.1-valve3
pkgver=${_tag//-/.}
pkgrel=3
pkgdesc='Steam Deck Linux kernel with Charcoal configuration'
url="https://github.com/Marctraider/linux-charcoal-conservative"
arch=(
  x86_64
)
license=(GPL-2.0-only)
makedepends=(
  bc
  binutils
  cpio
  gettext
  glibc
  libelf
  libgcc
  openssl
  pahole
  perl
  python
  rust
  rust-bindgen
  rust-src
  tar
  xxhash
  xz
  zlib
  zstd

  # Jupiter: we don't build docs, we don't need it's deps
  # # htmldocs
  # graphviz
  # imagemagick
  # python-sphinx
  # python-yaml
  # texlive-latexextra

  # Jupiter: we're using git+ssh for the source
  git
  openssh
  llvm
  clang
  lld
  polly
  curl
)
options=(
  !debug
  !strip
)
_srcname=archlinux-linux-charcoal-conservative
source=(
  "$_srcname::git+https://github.com/evlaV/linux-integration.git#tag=$_tag"
  config-valve-base
  config-valve-neptune
  config-neptune
  config-charcoal
  "clang-polly.patch::file://$PWD/patches/clang-polly.patch"
  "vangogh_allow_higher_cpu_freq.patch::file://$PWD/patches/vangogh_allow_higher_cpu_freq.patch"
  "amd-pstate-epp-boost.service::file://$PWD/systemd/amd-pstate-epp-boost.service"
)
sha256sums=(
  '502f1d9beb5f5320a6efd4fc02f9119c7d40cfa7b7f46da5e897d931f7a07c47'
  'ecd8c76eb203493e67ba4052e7bc1fa46f51c91566f102172e7a18d7de2dd5eb'
  'b91c3ed65067704c8fdb8289d44ed18aa62f98f52c3b6d91fb72bc5b1606ae79'
  'd88eaf0f94bae470040e4882f334c05b1bb2ab0a99e4b7299aa0b2337810ab8d'
  '7804e2f341c7b1a827b61075e4fb772ae05a518c16d16fc8585b94fa53d2fc3b'
  '2b09de51a50820647fe3c5b6947da8089a3d341ca6e76f689d994581a80a186b'
  'bed9736aaf79003ed6a979540f4cc77bce0d6429faf388d4d6d40d797605658a'
  'd0fc67545dcf738fa69853c43ceab858bc2f87cf5910ae1755c7092679ee3562'
)

# https://www.kernel.org/pub/linux/kernel/v7.x/sha256sums.asc

export KBUILD_BUILD_HOST=archlinux
export KBUILD_BUILD_USER=$pkgbase
export KBUILD_BUILD_TIMESTAMP="$(date -Ru${SOURCE_DATE_EPOCH:+d @$SOURCE_DATE_EPOCH})"

prepare() {
  cd $_srcname

  # Apply the requested per-core EPP RFC first, while the source checkout is
  # still clean and exactly at the pinned Valve tag.
  expected_source="6fbfd992c8fee6877006b53cca0110bc9586fc00"
  [[ "$(git rev-parse '7.3.1-valve3^{commit}')" == "$expected_source" ]] || {
    echo "error: kernel source tag resolved to an unexpected commit" >&2
    exit 1
  }
  git merge-base --is-ancestor "$expected_source" HEAD || {
    echo "error: kernel tree is not based on the pinned Valve source commit" >&2
    exit 1
  }

  if ! grep -Fq 'module_param_cb(epp_boost' drivers/cpufreq/amd-pstate.c; then
    bash "$startdir/scripts/apply-amd-epp-rfc.sh" "$PWD"
  else
    echo "AMD per-core EPP RFC already applied."
  fi

  # Keep the Git checkout clean until the RFC importer has completed.
  echo "Setting version..."
  echo "-$pkgrel" > localversion.10-pkgrel
  echo "${pkgbase#linux}" > localversion.20-pkgname

  echo "Applying Polly and Van Gogh frequency patches..."
  if ! grep -Fq 'config POLLY_CLANG' init/Kconfig; then
    patch --dry-run -Np1 < ../clang-polly.patch
    patch -Np1 < ../clang-polly.patch
  fi
  if ! grep -Fq 'smu->cpu_default_soft_max_freq = 4200;' drivers/gpu/drm/amd/pm/swsmu/smu11/vangogh_ppt.c; then
    grep -Fq 'smu->cpu_default_soft_max_freq = 3500;' drivers/gpu/drm/amd/pm/swsmu/smu11/vangogh_ppt.c || {
      echo "error: expected Valve 3500 MHz Van Gogh ceiling not found" >&2
      exit 1
    }
    patch --dry-run -Np1 < ../vangogh_allow_higher_cpu_freq.patch
    patch -Np1 < ../vangogh_allow_higher_cpu_freq.patch
  fi
  grep -Fq 'LLVMPolly.so' Makefile || {
    echo "error: Clang Polly Kbuild plugin flag is missing" >&2
    exit 1
  }

  echo "Generating the stock Valve Neptune configuration baseline..."
  baseline_config="$srcdir/config-valve-baseline"
  cp ../config-valve-base "$baseline_config"
  scripts/kconfig/merge_config.sh -m "$baseline_config" \
    ../config-valve-neptune
  make LLVM=1 KCONFIG_CONFIG="$baseline_config" olddefconfig

  echo "Merging Valve and Charcoal configurations..."
  cp ../config-valve-base .config
  scripts/kconfig/merge_config.sh -m .config \
    ../config-valve-neptune \
    ../config-neptune \
    ../config-charcoal
  make LLVM=1 olddefconfig

  # Save every y/m/n linkage-state change against the stock Valve Neptune
  # baseline. The runtime test uses this manifest to report all changed
  # built-in/module selections, rather than a hand-maintained feature list.
  {
    printf '# CONFIG_SYMBOL valve_state charcoal_state\n'
    awk '
      FNR == NR {
        if ($0 ~ /^CONFIG_[A-Za-z0-9_]+=*/) {
          key = $1; sub(/=.*/, "", key)
          value = $0; sub(/^[^=]*=/, "", value)
          valve[key] = value
        } else if ($0 ~ /^# CONFIG_[A-Za-z0-9_]+ is not set$/) {
          valve[$2] = "n"
        }
        next
      }
      {
        if ($0 ~ /^CONFIG_[A-Za-z0-9_]+=*/) {
          key = $1; sub(/=.*/, "", key)
          value = $0; sub(/^[^=]*=/, "", value)
          charcoal[key] = value
        } else if ($0 ~ /^# CONFIG_[A-Za-z0-9_]+ is not set$/) {
          charcoal[$2] = "n"
        }
      }
      END {
        for (key in valve) {
          if (!(key in charcoal)) charcoal[key] = "n"
          if (valve[key] != charcoal[key] &&
              (valve[key] == "y" || valve[key] == "m" ||
               charcoal[key] == "y" || charcoal[key] == "m"))
            printf "%s %s %s\n", key, valve[key], charcoal[key]
        }
        for (key in charcoal) {
          if (!(key in valve) &&
              (charcoal[key] == "y" || charcoal[key] == "m"))
            printf "%s n %s\n", key, charcoal[key]
        }
      }
    ' "$baseline_config" .config | sort
  } > "$srcdir/charcoal-linkage-diff"
  test -s "$srcdir/charcoal-linkage-diff" || {
    echo "error: generated Valve-to-Charcoal linkage manifest is empty" >&2
    exit 1
  }
  diff -u ../config-valve-base .config || :

  require_config() {
    grep -Fqx "$1" .config || {
      echo "error: required config missing: $1" >&2
      exit 1
    }
  }
  require_config_not_set() {
    grep -Fqx "# $1 is not set" .config || {
      echo "error: required config is not disabled: $1" >&2
      exit 1
    }
  }
  require_config_not_set 'CONFIG_CPU_MITIGATIONS'
  require_config 'CONFIG_SCHED_CLASS_EXT=y'
  require_config 'CONFIG_X86_AMD_PSTATE=y'
  require_config 'CONFIG_LTO_CLANG_FULL=y'
  require_config 'CONFIG_POLLY_CLANG=y'
  require_config 'CONFIG_DEBUG_INFO_BTF=y'
  require_config 'CONFIG_BPF_SYSCALL=y'
  require_config 'CONFIG_BPF_JIT=y'
  require_config 'CONFIG_CGROUPS=y'
  require_config 'CONFIG_JOYSTICK_XPAD=m'
  require_config 'CONFIG_JOYSTICK_XBOX_GIP=m'

  make LLVM=1 -s kernelrelease > version
  echo "Prepared $pkgbase version $(<version)"
}

build() {
  cd $_srcname

  # Full Clang LTO makes the final built-in kernel link memory intensive.
  # Build the built-in archive with normal parallelism, serialize vmlinux.o,
  # then resume the remaining targets in parallel.
  local kbuild_flags=(LLVM=1 KCFLAGS="-march=znver2 -O2")
  echo "Building built-in archive with -j2..."
  make "${kbuild_flags[@]}" -j2 vmlinux.a
  echo "Linking vmlinux.o with -j1 to limit peak memory..."
  make "${kbuild_flags[@]}" -j1 vmlinux_o
  echo "Resuming kernel build with -j2..."
  make "${kbuild_flags[@]}" -j2 all

  make LLVM=1 -C tools/bpf/bpftool vmlinux.h feature-clang-bpf-co-re=1
}

_package() {
  pkgdesc="The $pkgdesc kernel and modules"
  depends=(
    coreutils
    initramfs
    kmod
  )
  optdepends=(
    "$pkgbase-headers: headers and scripts for building modules"
    'linux-firmware: firmware images needed for some devices'
    'scx-scheds: to run the requested scx_lavd userspace scheduler'
    'wireless-regdb: to set the correct wireless channels of your country'
  )
  provides=(
    KSMBD-MODULE
    NTSYNC-MODULE
    VIRTUALBOX-GUEST-MODULES
    WIREGUARD-MODULE
  )
  replaces=(
    virtualbox-guest-modules-arch
    wireguard-arch
  )

  cd $_srcname
  local modulesdir="$pkgdir/usr/lib/modules/$(<version)"

  # Record the intended kernel compilation recipe alongside the installed image.
  install -d "$modulesdir"
  cat > "$modulesdir/charcoal-build-info" <<'BUILDINFO'
compiler=clang
llvm=1
cflags=-march=znver2 -O2
lto=clang-full
polly=enabled
BUILDINFO

  install -Dm644 "$srcdir/charcoal-linkage-diff" \
    "$modulesdir/charcoal-linkage-diff"

  echo "Installing boot image..."
  # systemd expects to find the kernel here to allow hibernation
  # https://github.com/systemd/systemd/commit/edda44605f06a41fb86b7ab8128dcf99161d2344
  install -Dm644 "$(make LLVM=1 -s image_name)" "$modulesdir/vmlinuz"

  # Used by mkinitcpio to name the kernel
  echo "$pkgbase" | install -Dm644 /dev/stdin "$modulesdir/pkgbase"

  # The installer may enable this unit after validating the target system.
  install -Dm644 "$srcdir/amd-pstate-epp-boost.service" \
    "$pkgdir/usr/lib/systemd/system/amd-pstate-epp-boost.service"

  echo "Installing modules..."
  ZSTD_CLEVEL=19 make LLVM=1 INSTALL_MOD_PATH="$pkgdir/usr" INSTALL_MOD_STRIP=1 \
    DEPMOD=/doesnt/exist modules_install  # Suppress depmod

  # remove build link
  rm "$modulesdir"/build
}

_package-headers() {
  pkgdesc="Headers and scripts for building modules for the $pkgdesc kernel"
  depends=(
    llvm
    clang
    lld
    polly
    binutils
    glibc
    libelf
    libgcc
    openssl
    pahole
    xxhash
    zlib
    zstd
  )
  provides=(LINUX-HEADERS)

  cd $_srcname
  local builddir="$pkgdir/usr/lib/modules/$(<version)/build"

  local karch
  case $CARCH in
    x86_64) karch=x86 ;;
    *) echo "Unknown CARCH $CARCH"; exit 1 ;;
  esac

  echo "Installing build files..."
  install -Dt "$builddir" -m644 .config Makefile Module.symvers System.map \
    localversion.* version vmlinux tools/bpf/bpftool/vmlinux.h
  install -Dt "$builddir/kernel" -m644 kernel/Makefile
  install -Dt "$builddir/arch/$karch" -m644 arch/$karch/Makefile
  cp -t "$builddir" -a scripts
  ln -srt "$builddir" "$builddir/scripts/gdb/vmlinux-gdb.py"

  if [[ $(scripts/config -s CONFIG_HAVE_STACK_VALIDATION) = y ]]; then
    install -Dt "$builddir/tools/objtool" tools/objtool/objtool
  fi

  if [[ $(scripts/config -s CONFIG_DEBUG_INFO_BTF_MODULES) = y ]]; then
    install -Dt "$builddir/tools/bpf/resolve_btfids" tools/bpf/resolve_btfids/resolve_btfids
  fi

  echo "Installing headers..."
  cp -t "$builddir" -a include
  cp -t "$builddir/arch/$karch" -a arch/$karch/include
  install -Dt "$builddir/arch/$karch/kernel" -m644 arch/$karch/kernel/asm-offsets.s

  install -Dt "$builddir/drivers/md" -m644 drivers/md/*.h
  install -Dt "$builddir/net/mac80211" -m644 net/mac80211/*.h

  # https://bugs.archlinux.org/task/13146
  install -Dt "$builddir/drivers/media/i2c" -m644 drivers/media/i2c/msp3400-driver.h

  # https://bugs.archlinux.org/task/20402
  install -Dt "$builddir/drivers/media/usb/dvb-usb" -m644 drivers/media/usb/dvb-usb/*.h
  install -Dt "$builddir/drivers/media/dvb-frontends" -m644 drivers/media/dvb-frontends/*.h
  install -Dt "$builddir/drivers/media/tuners" -m644 drivers/media/tuners/*.h

  # https://bugs.archlinux.org/task/71392
  install -Dt "$builddir/drivers/iio/common/hid-sensors" -m644 drivers/iio/common/hid-sensors/*.h

  echo "Installing KConfig files..."
  find . -name 'Kconfig*' -exec install -Dm644 {} "$builddir/{}" \;

  if [[ $(scripts/config -s CONFIG_RUST) = y ]]; then
    echo "Installing Rust files..."
    install -Dt "$builddir/rust" -m644 rust/*.rmeta
    install -Dt "$builddir/rust" rust/*.so
  fi

  echo "Installing unstripped VDSO..."
  make LLVM=1 INSTALL_MOD_PATH="$pkgdir/usr" vdso_install \
    link=  # Suppress build-id symlinks

  echo "Removing unneeded architectures..."
  local arch
  for arch in "$builddir"/arch/*/; do
    [[ $arch = */$karch/ ]] && continue
    echo "Removing $(basename "$arch")"
    rm -r "$arch"
  done

  echo "Removing documentation..."
  rm -r "$builddir/Documentation"

  echo "Removing broken symlinks..."
  find -L "$builddir" -type l -printf 'Removing %P\n' -delete

  echo "Removing loose objects..."
  find "$builddir" -type f -name '*.o' -printf 'Removing %P\n' -delete

  echo "Stripping build tools..."
  local file
  while read -rd '' file; do
    case "$(file -Sib "$file")" in
      application/x-sharedlib\;*)      # Libraries (.so)
        strip -v $STRIP_SHARED "$file" ;;
      application/x-archive\;*)        # Libraries (.a)
        strip -v $STRIP_STATIC "$file" ;;
      application/x-executable\;*)     # Binaries
        strip -v $STRIP_BINARIES "$file" ;;
      application/x-pie-executable\;*) # Relocatable binaries
        strip -v $STRIP_SHARED "$file" ;;
    esac
  done < <(find "$builddir" -type f -perm -u+x ! -name vmlinux -print0)

  echo "Stripping vmlinux..."
  strip -v $STRIP_STATIC "$builddir/vmlinux"

  echo "Adding symlink..."
  mkdir -p "$pkgdir/usr/src"
  ln -sr "$builddir" "$pkgdir/usr/src/$pkgbase"
}

_package-docs() {
  pkgdesc="Documentation for the $pkgdesc kernel"

  cd $_srcname
  local builddir="$pkgdir/usr/lib/modules/$(<version)/build"

  echo "Installing documentation..."
  local src dst
  while read -rd '' src; do
    dst="${src#Documentation/}"
    dst="$builddir/Documentation/${dst#output/}"
    install -Dm644 "$src" "$dst"
  done < <(
    find Documentation \( -name '.*' -o -name __pycache__ \) -prune \
      -o \! -type d -print0
  )

  echo "Adding symlink..."
  mkdir -p "$pkgdir/usr/share/doc"
  ln -sr "$builddir/Documentation" "$pkgdir/usr/share/doc/$pkgbase"
}

pkgname=(
  "$pkgbase"
  "$pkgbase-headers"
  # Jupiter: Don't package the docs
  # "$pkgbase-docs"
)
for _p in "${pkgname[@]}"; do
  eval "package_$_p() {
    $(declare -f "_package${_p#$pkgbase}")
    _package${_p#$pkgbase}
  }"
done

# vim:set ts=8 sts=2 sw=2 et:
