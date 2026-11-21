#!/usr/bin/env bash
# Install Charcoal Conservative and LAVD on SteamOS 3.10.
# Release downloads/checksum pins are intentionally deferred until assets are published.
set -Eeuo pipefail
IFS=$'\n\t'

readonly PKGBASE="linux-neptune-73"
readonly KERNEL_NAME="linux-neptune-73"
readonly HEADERS_NAME="linux-neptune-73-headers"
readonly SCX_NAME="scx-scheds"
readonly PRESET="/etc/mkinitcpio.d/linux-neptune-73.preset"
readonly VMLINUZ="/boot/vmlinuz-linux-neptune-73"
readonly INITRAMFS="/boot/initramfs-linux-neptune-73.img"
readonly WORKDIR="$(mktemp -d -t charcoal-installer.XXXXXX)"
readonly LOG="/tmp/charcoal-conservative-installer.log"

KERNEL_PKG=""
HEADERS_PKG=""
SCX_PKG=""
CHECK_ONLY=0
READONLY_DISABLED=0
TRANSACTION_STARTED=0
ROLLBACK_KERNEL=""
ROLLBACK_HEADERS=""
ROLLBACK_SCX=""
SCX_WAS_ACTIVE=0
SCX_WAS_ENABLED=0
SCX_CONFIG_EXISTED=0

die() { echo "ERROR: $*" >&2; exit 1; }
log() { printf '[%s] %s\n' "$(date '+%F %T')" "$*" | tee -a "$LOG"; }

update_bootloader() {
  if command -v steamos-update-grub >/dev/null; then
    steamos-update-grub
  elif command -v grub-mkconfig >/dev/null; then
    grub-mkconfig -o /boot/grub/grub.cfg
  else
    update-grub
  fi
}

cleanup() {
  local status=$?
  if (( status != 0 && TRANSACTION_STARTED )); then
    echo "Installation failed; attempting rollback..." >&2
    systemctl disable --now scx.service >/dev/null 2>&1 || true
    if (( SCX_CONFIG_EXISTED )); then
      cp -a "$WORKDIR/scx.default.backup" /etc/default/scx || echo "WARNING: could not restore /etc/default/scx" >&2
    else
      rm -f /etc/default/scx
    fi

    local restore=()
    [[ -n "$ROLLBACK_KERNEL" ]] && restore+=("$ROLLBACK_KERNEL")
    [[ -n "$ROLLBACK_HEADERS" ]] && restore+=("$ROLLBACK_HEADERS")
    [[ -n "$ROLLBACK_SCX" ]] && restore+=("$ROLLBACK_SCX")
    if (( ${#restore[@]} > 0 )); then
      pacman -U --noconfirm --overwrite='*' "${restore[@]}" || echo "WARNING: package rollback failed" >&2
    else
      echo "No cached previous packages were found; manual recovery may be required." >&2
    fi
    if [[ -z "$current_headers" ]]; then
      pacman -R --noconfirm "$HEADERS_NAME" >/dev/null 2>&1 || true
    fi
    if [[ -z "$current_scx" ]]; then
      pacman -R --noconfirm "$SCX_NAME" >/dev/null 2>&1 || true
    fi
    if (( SCX_WAS_ENABLED )); then systemctl enable scx.service || true; fi
    if (( SCX_WAS_ACTIVE )); then systemctl start scx.service || true; fi
    mkinitcpio -P || echo "WARNING: initramfs regeneration during rollback failed" >&2
    update_bootloader || echo "WARNING: GRUB update during rollback failed" >&2
  fi
  if (( READONLY_DISABLED )); then
    steamos-readonly enable || echo "WARNING: could not re-enable SteamOS read-only mode" >&2
  fi
  rm -rf "$WORKDIR"
  exit "$status"
}
trap cleanup EXIT

usage() {
  cat <<'USAGE'
Usage:
  sudo bash install-charcoal.sh --kernel KERNEL.pkg.tar.zst \
    --headers HEADERS.pkg.tar.zst --scx SCX-SCHEDS.pkg.tar.zst [--check-only]

Options:
  --kernel PATH    Charcoal Conservative linux-neptune-73 package
  --headers PATH   Matching linux-neptune-73-headers package
  --scx PATH       scx-scheds package containing scx_lavd and scx.service
  --check-only     Run preflight and optional package validation; do not install
  -h, --help       Show this help

Release downloads and checksum pins will be added after official assets exist.
USAGE
}

while (($#)); do
  case "$1" in
    --kernel) (($# >= 2)) || die "--kernel requires a path"; KERNEL_PKG="$2"; shift 2 ;;
    --headers) (($# >= 2)) || die "--headers requires a path"; HEADERS_PKG="$2"; shift 2 ;;
    --scx) (($# >= 2)) || die "--scx requires a path"; SCX_PKG="$2"; shift 2 ;;
    --check-only) CHECK_ONLY=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown argument: $1" ;;
  esac
done

[[ $EUID -eq 0 ]] || die "run as root"
command -v pacman >/dev/null || die "pacman not found"
command -v steamos-readonly >/dev/null || die "SteamOS read-only utility not found"
[[ -r /etc/os-release ]] || die "cannot read /etc/os-release"
# shellcheck disable=SC1091
source /etc/os-release
[[ "${ID:-}" == "steamos" ]] || die "SteamOS required (detected ID=${ID:-unknown})"
[[ "${VERSION_ID:-}" == 3.10* ]] || die "SteamOS 3.10 required (detected ${VERSION_ID:-unknown})"
[[ "$(uname -m)" == x86_64 ]] || die "Steam Deck x86_64 userspace required"

for cmd in bsdtar mkinitcpio systemctl; do
  command -v "$cmd" >/dev/null || die "$cmd not found"
done
[[ -f "$PRESET" ]] || die "expected mkinitcpio preset missing: $PRESET"
[[ -e "$VMLINUZ" ]] || die "expected Neptune kernel image missing: $VMLINUZ"
[[ -e "$INITRAMFS" ]] || die "expected initramfs missing: $INITRAMFS"
command -v steamos-update-grub >/dev/null || command -v grub-mkconfig >/dev/null || command -v update-grub >/dev/null || die "no supported GRUB update command found"

installed_version() {
  pacman -Q "$1" 2>/dev/null | awk '{print $2}' || true
}
find_cached_package() {
  local name="$1" version="$2" f
  [[ -n "$version" ]] || return 0
  for f in /var/cache/pacman/pkg/"$name"-"$version"-*.pkg.tar.*; do
    [[ -f "$f" ]] && { printf '%s\n' "$f"; return 0; }
  done
  return 0
}
validate_package() {
  local file="$1" expected="$2" name version
  [[ -f "$file" ]] || die "package not found: $file"
  name="$(pacman -Qp --print-format '%n' "$file")" || die "cannot read package metadata: $file"
  version="$(pacman -Qp --print-format '%v' "$file")" || die "cannot read package version: $file"
  [[ "$name" == "$expected" ]] || die "$file is $name, expected $expected"
  printf '%s\n' "$version"
}

kernel_version=""
headers_version=""
scx_version=""
module_version=""
if [[ -n "$KERNEL_PKG" || -n "$HEADERS_PKG" || -n "$SCX_PKG" ]]; then
  [[ -n "$KERNEL_PKG" && -n "$HEADERS_PKG" && -n "$SCX_PKG" ]] || die "supply all three package paths"
  kernel_version="$(validate_package "$KERNEL_PKG" "$KERNEL_NAME")"
  headers_version="$(validate_package "$HEADERS_PKG" "$HEADERS_NAME")"
  [[ "$kernel_version" == "$headers_version" ]] || die "kernel and headers package versions differ"

  kernel_listing="$(bsdtar -tf "$KERNEL_PKG")"
  grep -Eq '^usr/lib/modules/[^/]+/pkgbase$' <<<"$kernel_listing" || die "kernel package has no module pkgbase marker"
  pkgbase_path="$(grep -E '^usr/lib/modules/[^/]+/pkgbase$' <<<"$kernel_listing" | head -n1)"
  pkgbase_value="$(bsdtar -xOf "$KERNEL_PKG" "$pkgbase_path" | tr -d '\r\n')"
  [[ "$pkgbase_value" == "$PKGBASE" ]] || die "kernel pkgbase is '$pkgbase_value', expected '$PKGBASE'"
  module_version="${pkgbase_path#usr/lib/modules/}"
  module_version="${module_version%/pkgbase}"
  headers_listing="$(bsdtar -tf "$HEADERS_PKG")"
  grep -Fq "usr/lib/modules/$module_version/" <<<"$headers_listing" || die "headers package does not contain module tree $module_version"

  scx_version="$(validate_package "$SCX_PKG" "$SCX_NAME")"
  scx_listing="$(bsdtar -tf "$SCX_PKG")"
  grep -Fxq 'usr/bin/scx_lavd' <<<"$scx_listing" || die "scx-scheds package lacks /usr/bin/scx_lavd"
  grep -Fxq 'usr/lib/systemd/system/scx.service' <<<"$scx_listing" || die "scx-scheds package lacks scx.service"
fi
if (( ! CHECK_ONLY )); then
  [[ -n "$KERNEL_PKG" && -n "$HEADERS_PKG" && -n "$SCX_PKG" ]] || die "all three package paths are required"
fi

current_kernel="$(installed_version "$KERNEL_NAME")"
current_headers="$(installed_version "$HEADERS_NAME")"
current_scx="$(installed_version "$SCX_NAME")"
if [[ -n "$current_kernel" ]]; then
  ROLLBACK_KERNEL="$(find_cached_package "$KERNEL_NAME" "$current_kernel")"
  [[ -n "$ROLLBACK_KERNEL" ]] || die "no cached previous $KERNEL_NAME package; refusing upgrade without rollback"
fi
if [[ -n "$current_headers" ]]; then
  ROLLBACK_HEADERS="$(find_cached_package "$HEADERS_NAME" "$current_headers")"
  [[ -n "$ROLLBACK_HEADERS" ]] || die "no cached previous $HEADERS_NAME package; refusing upgrade without rollback"
fi
if [[ -n "$current_scx" ]]; then
  ROLLBACK_SCX="$(find_cached_package "$SCX_NAME" "$current_scx")"
  [[ -n "$ROLLBACK_SCX" ]] || die "no cached previous $SCX_NAME package; refusing upgrade without rollback"
fi

log "SteamOS ${VERSION_ID}; kernel ${kernel_version:-not supplied}; headers ${headers_version:-not supplied}; LAVD ${scx_version:-not supplied}"
log "Installed kernel: ${current_kernel:-none}; headers: ${current_headers:-none}; scx-scheds: ${current_scx:-none}"
if (( CHECK_ONLY )); then
  echo "Check-only passed. No packages or boot configuration were changed."
  exit 0
fi

echo "This installs/replaces the Conservative kernel and headers, plus LAVD userspace."
echo "LAVD will be configured as scx_lavd --performance and enabled at boot."
echo "No automatic reboot will occur."
read -r -p "Continue? [y/N] " answer
[[ "$answer" =~ ^[Yy]$ ]] || { echo "Cancelled."; exit 0; }

SCX_WAS_ACTIVE=0
SCX_WAS_ENABLED=0
systemctl is-active --quiet scx.service && SCX_WAS_ACTIVE=1 || true
systemctl is-enabled --quiet scx.service && SCX_WAS_ENABLED=1 || true
if [[ -e /etc/default/scx ]]; then
  SCX_CONFIG_EXISTED=1
  cp -a /etc/default/scx "$WORKDIR/scx.default.backup"
fi

steamos-readonly disable
READONLY_DISABLED=1
TRANSACTION_STARTED=1

log "Installing kernel, headers, and LAVD userspace in one pacman transaction"
pacman -U --noconfirm "$KERNEL_PKG" "$HEADERS_PKG" "$SCX_PKG"

log "Configuring LAVD performance mode"
install -d -m755 /etc/default
cat > /etc/default/scx <<'SCXCONF'
SCX_SCHEDULER=scx_lavd
SCX_FLAGS=--performance
SCXCONF
systemctl daemon-reload
systemctl enable scx.service
if [[ -d /sys/kernel/sched_ext ]]; then
  systemctl start scx.service
  systemctl is-active --quiet scx.service || die "scx.service failed to start on the running sched_ext kernel"
  pgrep -x scx_lavd >/dev/null || die "scx_lavd process is not running"
else
  log "LAVD is enabled at boot; activation waits until the new sched_ext kernel is booted."
fi

log "Regenerating initramfs"
mkinitcpio -P
log "Updating GRUB"
update_bootloader
[[ -s "$VMLINUZ" ]] || die "kernel image missing after installation"
[[ -s "$INITRAMFS" ]] || die "initramfs missing after installation"
[[ -f "$PRESET" ]] || die "mkinitcpio preset missing after installation"
pacman -Q "$KERNEL_NAME" "$HEADERS_NAME" "$SCX_NAME" || die "installed package verification failed"

TRANSACTION_STARTED=0
log "Installation completed; LAVD is configured with --performance and enabled at boot."
echo "Installation completed. LAVD is configured for --performance. Reboot manually when ready."
