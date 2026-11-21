#!/usr/bin/env bash
# Install the Charcoal Conservative SteamOS kernel from locally supplied packages.
# Release downloading/checksum pins are intentionally omitted until packages are published.
set -Eeuo pipefail
IFS=$'\n\t'

readonly PKGBASE="linux-neptune-73"
readonly KERNEL_NAME="linux-neptune-73"
readonly HEADERS_NAME="linux-neptune-73-headers"
readonly PRESET="/etc/mkinitcpio.d/linux-neptune-73.preset"
readonly VMLINUZ="/boot/vmlinuz-linux-neptune-73"
readonly INITRAMFS="/boot/initramfs-linux-neptune-73.img"
readonly WORKDIR="$(mktemp -d -t charcoal-installer.XXXXXX)"
readonly LOG="/var/log/charcoal-conservative-installer.log"

KERNEL_PKG=""
HEADERS_PKG=""
CHECK_ONLY=0
READONLY_DISABLED=0
TRANSACTION_STARTED=0
ROLLBACK_KERNEL=""
ROLLBACK_HEADERS=""

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
    echo "Installation failed; attempting package rollback..." >&2
    if [[ -n "$ROLLBACK_KERNEL" ]]; then
      local args=("$ROLLBACK_KERNEL")
      [[ -n "$ROLLBACK_HEADERS" ]] && args+=("$ROLLBACK_HEADERS")
      pacman -U --noconfirm --overwrite='*' "${args[@]}" || echo "WARNING: package rollback failed" >&2
      mkinitcpio -P || echo "WARNING: initramfs rollback regeneration failed" >&2
      update_bootloader || echo "WARNING: GRUB rollback update failed" >&2
    else
      echo "No previous cached kernel package exists; manual recovery may be required." >&2
    fi
  fi
  if (( READONLY_DISABLED )); then
    steamos-readonly enable || echo "WARNING: could not re-enable SteamOS read-only mode" >&2
  fi
  rm -rf "$WORKDIR"
  exit "$status"
}
trap cleanup EXIT

die() { echo "ERROR: $*" >&2; exit 1; }
log() { printf '[%s] %s\n' "$(date '+%F %T')" "$*" | tee -a "$LOG"; }
usage() {
  cat <<'USAGE'
Usage:
  sudo ./install-charcoal.sh --kernel /path/to/linux-neptune-73.pkg.tar.zst \
       --headers /path/to/linux-neptune-73-headers.pkg.tar.zst [--check-only]

Options:
  --kernel PATH    Conservative kernel package
  --headers PATH   Matching kernel headers package
  --check-only     Validate Deck state and package metadata without changing it
  -h, --help       Show this help

Packages are supplied locally for now. Release downloads and checksum pins will
be added only after the official release assets are published.
USAGE
}
while (($#)); do
  case "$1" in
    --kernel) (($# >= 2)) || die "--kernel requires a path"; KERNEL_PKG="$2"; shift 2 ;;
    --headers) (($# >= 2)) || die "--headers requires a path"; HEADERS_PKG="$2"; shift 2 ;;
    --check-only) CHECK_ONLY=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown argument: $1" ;;
  esac
done

[[ $EUID -eq 0 ]] || die "run with sudo/root"
command -v pacman >/dev/null || die "pacman not found"
command -v steamos-readonly >/dev/null || die "this does not appear to be SteamOS"
[[ -r /etc/os-release ]] || die "cannot read /etc/os-release"
# shellcheck disable=SC1091
source /etc/os-release
[[ "${ID:-}" == "steamos" ]] || die "SteamOS is required (detected ID=${ID:-unknown})"
[[ "${VERSION_ID:-}" == 3.10* ]] || die "SteamOS 3.10 is required (detected ${VERSION_ID:-unknown})"
[[ "$(uname -m)" == x86_64 ]] || die "Steam Deck x86_64 userspace is required"

for cmd in bsdtar pacman-query mkinitcpio; do
  if [[ $cmd == pacman-query ]]; then command -v pacman >/dev/null || die "pacman missing"; else command -v "$cmd" >/dev/null || die "$cmd not found"; fi
done

[[ -f "$PRESET" ]] || die "expected mkinitcpio preset missing: $PRESET"
[[ -e "$VMLINUZ" ]] || die "expected Valve/Neptune kernel image missing: $VMLINUZ"
[[ -e "$INITRAMFS" ]] || die "expected initramfs missing: $INITRAMFS"
command -v steamos-update-grub >/dev/null || { command -v grub-mkconfig >/dev/null || command -v update-grub >/dev/null || die "no supported GRUB update command found"; }

installed_version() {
  pacman -Q "$1" 2>/dev/null | awk '{print $2}' || true
}
find_cached_package() {
  local name="$1" version="$2" f
  [[ -n "$version" ]] || return 0
  for f in /var/cache/pacman/pkg/"$name"-"$version"-"*.pkg.tar.*; do
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
  [[ "$version" != *-debug* ]] || die "debug package supplied instead of $expected"
  printf '%s\n' "$version"
}
kernel_version=""
headers_version=""
module_version=""
if [[ -n "$KERNEL_PKG" || -n "$HEADERS_PKG" ]]; then
  [[ -n "$KERNEL_PKG" && -n "$HEADERS_PKG" ]] || die "supply both --kernel and --headers"
  kernel_version="$(validate_package "$KERNEL_PKG" "$KERNEL_NAME")"
  headers_version="$(validate_package "$HEADERS_PKG" "$HEADERS_NAME")"
  [[ "$kernel_version" == "$headers_version" ]] || die "kernel and headers versions differ ($kernel_version vs $headers_version)"
  kernel_listing="$(bsdtar -tf "$KERNEL_PKG")"
  grep -Eq '^usr/lib/modules/[^/]+/pkgbase$' <<<"$kernel_listing" || die "kernel package has no module pkgbase marker"
  pkgbase_path="$(grep -E '^usr/lib/modules/[^/]+/pkgbase$' <<<"$kernel_listing" | head -n1)"
  pkgbase_value="$(bsdtar -xOf "$KERNEL_PKG" "$pkgbase_path" | tr -d '\r\n')"
  [[ "$pkgbase_value" == "$PKGBASE" ]] || die "kernel module pkgbase is '$pkgbase_value', expected '$PKGBASE'"
  module_version="${pkgbase_path#usr/lib/modules/}"
  module_version="${module_version%/pkgbase}"
  headers_listing="$(bsdtar -tf "$HEADERS_PKG")"
  grep -Fq "usr/lib/modules/$module_version/build/" <<<"$headers_listing" || die "headers package does not match kernel module version $module_version"
fi
if (( ! CHECK_ONLY )); then
  [[ -n "$KERNEL_PKG" && -n "$HEADERS_PKG" ]] || die "both --kernel and --headers are required"
fi
current_kernel="$(installed_version "$KERNEL_NAME")"
current_headers="$(installed_version "$HEADERS_NAME")"
if [[ -n "$current_kernel" ]]; then
  ROLLBACK_KERNEL="$(find_cached_package "$KERNEL_NAME" "$current_kernel")"
  [[ -n "$ROLLBACK_KERNEL" ]] || die "no cached copy of installed $KERNEL_NAME $current_kernel; refusing an upgrade without rollback"
fi
if [[ -n "$current_headers" ]]; then
  ROLLBACK_HEADERS="$(find_cached_package "$HEADERS_NAME" "$current_headers")"
  [[ -n "$ROLLBACK_HEADERS" ]] || die "no cached copy of installed $HEADERS_NAME $current_headers; refusing an upgrade without rollback"
fi

log "SteamOS ${VERSION_ID}; target kernel ${kernel_version:-not supplied}; module tree ${module_version:-not checked}"
log "Installed kernel: ${current_kernel:-none}; headers: ${current_headers:-none}"
log "Boot preset and existing boot files are present."
if (( CHECK_ONLY )); then
  echo "Check-only passed. No system changes were made."
  exit 0
fi

[[ -n "$KERNEL_PKG" && -n "$HEADERS_PKG" ]] || die "both --kernel and --headers are required"
echo
echo "This will replace the installed linux-neptune-73 package with Charcoal Conservative."
echo "The Valve package identity and boot paths are retained."
echo "No automatic reboot will occur."
read -r -p "Continue? [y/N] " answer
[[ "$answer" =~ ^[Yy]$ ]] || { echo "Cancelled."; exit 0; }

steamos-readonly disable
READONLY_DISABLED=1
TRANSACTION_STARTED=1
rollback() {
  local rc=$?
  if (( rc != 0 && TRANSACTION_STARTED )); then
    echo "Installation failed; attempting package rollback..." >&2
    if [[ -n "$ROLLBACK_KERNEL" ]]; then
      local args=("$ROLLBACK_KERNEL")
      [[ -n "$ROLLBACK_HEADERS" ]] && args+=("$ROLLBACK_HEADERS")
      pacman -U --noconfirm --overwrite='*' "${args[@]}" || echo "WARNING: package rollback failed" >&2
      mkinitcpio -P || echo "WARNING: initramfs rollback regeneration failed" >&2
      update_bootloader || echo "WARNING: GRUB rollback update failed" >&2
    else
      echo "No previous cached kernel package exists; manual recovery may be required." >&2
    fi
  fi
  return "$rc"
}
update_bootloader() {
  if command -v steamos-update-grub >/dev/null; then
    steamos-update-grub
  elif command -v grub-mkconfig >/dev/null; then
    grub-mkconfig -o /boot/grub/grub.cfg
  else
    update-grub
  fi
}
trap rollback ERR

log "Installing kernel and matching headers as one pacman transaction"
pacman -U --noconfirm "$KERNEL_PKG" "$HEADERS_PKG"
log "Regenerating initramfs presets"
mkinitcpio -P
log "Updating GRUB"
update_bootloader
[[ -s "$VMLINUZ" ]] || die "kernel image missing after installation"
[[ -s "$INITRAMFS" ]] || die "initramfs missing after installation"
[[ -f "$PRESET" ]] || die "mkinitcpio preset missing after installation"
pacman -Q "$KERNEL_NAME" "$HEADERS_NAME" || die "installed package verification failed"
TRANSACTION_STARTED=0
trap - ERR
log "Installation completed. Reboot manually when ready."
echo "Charcoal Conservative is installed. Reboot manually when convenient."
