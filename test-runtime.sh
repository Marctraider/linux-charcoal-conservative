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
