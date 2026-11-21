#!/usr/bin/env bash
# Runtime verification for Charcoal Conservative on SteamOS / Steam Deck.
# Read-only: this script does not change kernel, scheduler, or power settings.
set -uo pipefail

PASS=0
FAIL=0
WARN=0

pass() { printf '[PASS] %s\n' "$*"; PASS=$((PASS + 1)); }
fail() { printf '[FAIL] %s\n' "$*" >&2; FAIL=$((FAIL + 1)); }
warn() { printf '[WARN] %s\n' "$*"; WARN=$((WARN + 1)); }

read_config_value() {
  local key="$1" file
  if [[ -r /proc/config.gz ]] && command -v zcat >/dev/null 2>&1; then
    zcat /proc/config.gz 2>/dev/null | grep -E "^(CONFIG_${key}=|# CONFIG_${key} is not set)$" | tail -n1
    return
  fi
  for file in "/boot/config-$(uname -r)" "/usr/lib/modules/$(uname -r)/build/.config"; do
    if [[ -r "$file" ]]; then
      grep -E "^(CONFIG_${key}=|# CONFIG_${key} is not set)$" "$file" | tail -n1
      return
    fi
  done
}

printf 'Charcoal Conservative runtime check\n'
printf 'Kernel: %s\n\n' "$(uname -r)"
config_file=""
if [[ -r /proc/config.gz ]] && command -v zcat >/dev/null 2>&1; then
  config_file=/proc/config.gz
elif [[ -r "/boot/config-$(uname -r)" ]]; then
  config_file="/boot/config-$(uname -r)"
elif [[ -r "/usr/lib/modules/$(uname -r)/build/.config" ]]; then
  config_file="/usr/lib/modules/$(uname -r)/build/.config"
fi

config_line() {
  local key="$1"
  if [[ "$config_file" == /proc/config.gz ]]; then
    zcat "$config_file" 2>/dev/null | grep -E "^(CONFIG_${key}=|# CONFIG_${key} is not set)$" | tail -n1
  elif [[ -n "$config_file" ]]; then
    grep -E "^(CONFIG_${key}=|# CONFIG_${key} is not set)$" "$config_file" | tail -n1
  fi
}

config_state() {
  local key="$1" line
  line="$(config_line "$key" || true)"
  case "$line" in
    "CONFIG_${key}=y") printf "built-in (=y)" ;;
    "CONFIG_${key}=m") printf "module (=m)" ;;
    "CONFIG_${key}=n"|"# CONFIG_${key} is not set") printf "disabled" ;;
    "") printf "unknown (config unavailable)" ;;
    *) printf "%s" "$line" ;;
  esac
}

printf "\nBuild configuration:\n"
if [[ -z "$config_file" ]]; then
  warn 'Running kernel config is unavailable; cannot verify compiler/LTO/Polly settings'
else
  printf "  Config source: %s\n" "$config_file"
  for key in CC_IS_CLANG LTO_CLANG LTO_CLANG_FULL POLLY_CLANG; do
    printf "  %-20s %s\n" "CONFIG_$key" "$(config_state "$key")"
  done
  for key in CC_IS_CLANG LTO_CLANG_FULL POLLY_CLANG; do
    line="$(config_line "$key" || true)"
    if [[ "$line" == "CONFIG_${key}=y" ]]; then
      pass "CONFIG_$key is enabled"
    else
      fail "CONFIG_$key is not enabled (found: ${line:-unknown})"
    fi
  done
fi

# This marker records the package build recipe; it is not independent binary introspection.
build_info="/usr/lib/modules/$(uname -r)/charcoal-build-info"
if [[ -r "$build_info" ]]; then
  printf "\nCharcoal build recipe metadata:\n"
  sed "s/^/  /" "$build_info"
  for expected in "compiler=clang" "cflags=-march=znver2" "lto=clang-full" "polly=enabled"; do
    grep -Fxq "$expected" "$build_info" && pass "Build metadata: $expected" || fail "Build metadata missing: $expected"
  done
else
  warn 'Charcoal build metadata marker not found; this kernel may predate the marker or not be this package'
fi

linkage_manifest="/usr/lib/modules/$(uname -r)/charcoal-linkage-diff"
if [[ -r "$linkage_manifest" ]]; then
  printf "\nLinkage and Clang Full LTO:\n"
  printf '  Built-in features (=y) are linked into vmlinux, allowing Clang Full LTO\n'
  printf '  to optimize across their code. Modules (=m) are linked separately, so\n'
  printf '  they are outside that same whole-kernel link-time optimization pass.\n'
  printf '  These are configuration differences from Valve; not every change is\n'
  printf '  necessarily LTO-driven (some support boot or hardware functionality).\n'
  printf "\nValve baseline -> Charcoal linkage changes (only changed built-in/module selections):\n"
  printf '  %-42s %-12s %-12s %-12s\n' 'Kernel option' 'Valve' 'Charcoal' 'Running'
  linkage_mismatch=0
  linkage_builtin=0
  linkage_modules=0
  linkage_changes=0
  while read -r symbol valve_state charcoal_state; do
    [[ -z "$symbol" || "$symbol" == \#* ]] && continue
    key="${symbol#CONFIG_}"
    actual_line="$(config_line "$key" || true)"
    case "$actual_line" in
      "CONFIG_${key}=y") actual_state=y ;;
      "CONFIG_${key}=m") actual_state=m ;;
      "CONFIG_${key}=n"|"# CONFIG_${key} is not set") actual_state=n ;;
      *) actual_state=unknown ;;
    esac
    printf '  %-42s %-12s %-12s %-12s\n' "$symbol" "$valve_state" "$charcoal_state" "$actual_state"
    linkage_changes=$((linkage_changes + 1))
    [[ "$charcoal_state" == y ]] && linkage_builtin=$((linkage_builtin + 1))
    [[ "$charcoal_state" == m ]] && linkage_modules=$((linkage_modules + 1))
    if [[ "$actual_state" != unknown && "$actual_state" != "$charcoal_state" ]]; then
      fail "$symbol running state is $actual_state; package expects $charcoal_state"
      linkage_mismatch=1
    fi
  done < "$linkage_manifest"
  printf '  Changed options: %d; Charcoal built-in: %d; Charcoal modules: %d\n' \
    "$linkage_changes" "$linkage_builtin" "$linkage_modules"
  if (( linkage_mismatch == 0 )); then
    if [[ -n "$config_file" ]]; then
      pass 'All Valve-to-Charcoal linkage changes match the running kernel config'
    else
      warn 'Linkage manifest is present, but running kernel config is unavailable for verification'
    fi
  fi
else
  warn 'Valve-to-Charcoal linkage manifest is unavailable; showing selected features only'
  printf "\nSelected Steam Deck / LTO-related feature linkage:\n"
  for key in TLS INPUT_UINPUT SOUND SND SND_HRTIMER SND_SOC INPUT_JOYDEV INPUT_MOUSEDEV HID_GENERIC HID_MULTITOUCH RFKILL CRYPTO_AES_NI_INTEL BLK_DEV_NVME SPI_AMD EXT4_FS BTRFS_FS OVERLAY_FS VFAT_FS MMC MMC_SDHCI BT BT_RFCOMM I2C_CHARDEV SND_AMD_ACP_CONFIG CRYPTO_LZ4 CRYPTO_DEV_CCP_DD CRYPTO_DEV_CCP_CRYPTO HID_STEAM MFD_STEAMDECK LEDS_STEAMDECK SENSORS_STEAMDECK I2C_PIIX4 IIO LTRF216A MMC_BLOCK MMC_SDHCI_PCI POWER_SEQUENCING BT_HCIUART I2C_HID I2C_HID_ACPI SND_SOC_MAX98388 EXTCON_STEAMDECK SOUNDWIRE SOUNDWIRE_AMD SND_SOC_NAU8821 SND_SOC_SOF_PCI F2FS_FS LEDS_CLASS_MULTICOLOR LEDS_VALVE JOYSTICK_XPAD JOYSTICK_XBOX_GIP; do
    printf "  %-32s %s\n" "CONFIG_$key" "$(config_state "$key")"
  done
fi

# CPU mitigations: verify the running kernel's actual build config.
mitigation_config="$(read_config_value CPU_MITIGATIONS || true)"
if [[ "$mitigation_config" == '# CONFIG_CPU_MITIGATIONS is not set' ]]; then
  pass 'CONFIG_CPU_MITIGATIONS is disabled in the running kernel'
elif [[ "$mitigation_config" == 'CONFIG_CPU_MITIGATIONS=y' ]]; then
  fail 'CONFIG_CPU_MITIGATIONS is enabled in the running kernel'
else
  fail 'Cannot determine CONFIG_CPU_MITIGATIONS from the running kernel config'
fi

# Print vulnerability status as supporting runtime evidence; values vary by CPU.
if [[ -d /sys/devices/system/cpu/vulnerabilities ]]; then
  printf '\nCPU vulnerability status (informational):\n'
  for f in /sys/devices/system/cpu/vulnerabilities/*; do
    [[ -r "$f" ]] || continue
    printf '  %s: %s\n' "${f##*/}" "$(cat "$f")"
  done
else
  warn 'CPU vulnerability sysfs status directory is unavailable'
fi

# AMD P-State per-core EPP boost is enabled by a dedicated oneshot service.
epp_param=/sys/module/amd_pstate/parameters/epp_boost
if [[ -r "$epp_param" ]]; then
  epp_value="$(tr -d '[:space:]' < "$epp_param")"
  if [[ "$epp_value" == 1 || "$epp_value" == Y || "$epp_value" == y || "$epp_value" == true ]]; then
    pass 'amd_pstate epp_boost runtime parameter is 1'
  else
    fail "amd_pstate epp_boost is '$epp_value', expected 1"
  fi
else
  fail "AMD P-State epp_boost parameter is unavailable ($epp_param)"
fi
pstate_status=/sys/devices/system/cpu/amd_pstate/status
if [[ -r "$pstate_status" ]]; then
  pstate_mode="$(tr -d '[:space:]' < "$pstate_status")"
  if [[ "$pstate_mode" == active ]]; then
    pass 'AMD P-State driver is in active mode'
  else
    fail "AMD P-State driver mode is '$pstate_mode', expected active"
  fi
else
  fail "AMD P-State status is unavailable ($pstate_status)"
fi
if command -v systemctl >/dev/null 2>&1; then
  if systemctl is-active --quiet amd-pstate-epp-boost.service; then
    pass 'amd-pstate-epp-boost.service is active'
  else
    fail 'amd-pstate-epp-boost.service is not active'
  fi
  if systemctl is-enabled --quiet amd-pstate-epp-boost.service; then
    pass 'amd-pstate-epp-boost.service is enabled at boot'
  else
    fail 'amd-pstate-epp-boost.service is not enabled at boot'
  fi
else
  fail 'systemctl is unavailable; cannot verify EPP boost service'
fi

# The Van Gogh soft maximum is expected to be 4200 MHz (4200000 kHz).
shopt -s nullglob
policies=(/sys/devices/system/cpu/cpufreq/policy*)
if (( ${#policies[@]} == 0 )); then
  fail 'No CPU cpufreq policies found'
else
  freq_bad=0
  printf '\nCPU policy maximum frequencies:\n'
  for policy in "${policies[@]}"; do
    max_file="$policy/scaling_max_freq"
    if [[ ! -r "$max_file" ]]; then
      printf '  %s: unavailable\n' "${policy##*/}"
      freq_bad=1
      continue
    fi
    max_khz="$(tr -d '[:space:]' < "$max_file")"
    printf '  %s: %s kHz\n' "${policy##*/}" "$max_khz"
    [[ "$max_khz" == 4200000 ]] || freq_bad=1
  done
  if (( freq_bad == 0 )); then
    pass 'All CPU cpufreq policies report a 4200 MHz scaling maximum'
  else
    fail 'One or more CPU policies do not report a 4200 MHz scaling maximum'
  fi
fi

# Confirm that sched_ext is running LAVD and that the live process has --performance.
if command -v systemctl >/dev/null 2>&1 && systemctl is-active --quiet scx.service; then
  pass 'scx.service is active'
else
  fail 'scx.service is not active'
fi
lavd_pid=''
if command -v pgrep >/dev/null 2>&1; then
  lavd_pid="$(pgrep -x scx_lavd | head -n1 || true)"
fi
if [[ -n "$lavd_pid" && -r "/proc/$lavd_pid/cmdline" ]]; then
  lavd_args="$(tr '\0' ' ' < "/proc/$lavd_pid/cmdline")"
  printf 'LAVD process: %s\n' "$lavd_args"
  if [[ " $lavd_args " == *' --performance '* ]]; then
    pass 'Live scx_lavd process is running with --performance'
  else
    fail 'scx_lavd is running, but its live command line lacks --performance'
  fi
else
  fail 'No running scx_lavd process found'
fi
if [[ -r /sys/kernel/sched_ext/root/ops ]]; then
  ops="$(cat /sys/kernel/sched_ext/root/ops)"
  printf 'sched_ext root ops: %s\n' "$ops"
  [[ "$ops" == *lavd* ]] && pass 'sched_ext reports LAVD as the active root scheduler' || fail "sched_ext active root scheduler is '$ops', expected LAVD"
elif [[ -r /sys/kernel/sched_ext/ops ]]; then
  ops="$(cat /sys/kernel/sched_ext/ops)"
  printf 'sched_ext ops: %s\n' "$ops"
  [[ "$ops" == *lavd* ]] && pass 'sched_ext reports LAVD as the active scheduler' || fail "sched_ext active scheduler is '$ops', expected LAVD"
else
  fail 'Cannot read the sched_ext active scheduler name from sysfs'
fi

printf '\nSummary: %d passed, %d failed, %d warnings\n' "$PASS" "$FAIL" "$WARN"
(( FAIL == 0 ))
