#!/usr/bin/env bash
set -Eeuo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${ROOT_DIR}/scripts/common.sh"
mode="${1:---resume}"
[[ $# -le 1 ]] || fail "Expected one mode. See --help."
case "$mode" in
  --help|-h)
    echo "Usage: bash bootstrap.sh [--resume|--rerun|--repair-gui|--reset]"
    echo "Default: resume unfinished setup. --rerun reapplies every step, including updates."
    echo "--repair-gui restores sensors/UPS display without a system upgrade."
    echo "--reset clears completion markers and exits; reboot checkpoints are retained."
    exit 0 ;;
  --resume|--rerun|--repair-gui|--reset) ;;
  *) fail "Unknown mode: $mode (see --help)" ;;
esac
require_root
mkdir -p "$STATE_DIR"
exec 9>"$STATE_DIR/bootstrap.lock"
flock -n 9 || fail "Another bootstrap process is running."
if [[ "$mode" == --reset ]]; then
  rm -f "$STATE_DIR"/*.done
  echo "Completion markers cleared."
  exit 0
fi
load_config "$ROOT_DIR" "$mode"
if [[ "$mode" == --repair-gui ]]; then
  bash "$ROOT_DIR/scripts/sensors.sh"
  exit 0
fi
boot_id=$(cat /proc/sys/kernel/random/boot_id)
checkpoint="$STATE_DIR/update-reboot"
if [[ -f "$checkpoint" ]]; then
  [[ $(head -n 1 "$checkpoint") != "$boot_id" ]] || {
    echo "Package update completed. Reboot the host, then run: bash $ROOT_DIR/bootstrap.sh"
    exit 0
  }
  # Record success before removing the checkpoint: interruption cannot repeat updates.
  mode=$(sed -n '2p' "$checkpoint")
  mode="${mode:---resume}"
  resumed_update=true
  mark_step_done post_install
  rm -f "$checkpoint"
  # Resume the remaining steps even if --rerun was supplied after reboot.
fi
export RERUN=false
[[ "$mode" != --rerun ]] || export RERUN=true
bash "$ROOT_DIR/scripts/repos.sh"
if [[ "${resumed_update:-false}" != true ]] && { [[ "$RERUN" == true ]] || ! is_step_done post_install; }; then
  clear_step_done post_install
  # Invalidate dependent configuration BEFORE updating so a failed rerun can
  # subsequently resume without silently skipping old completion markers.
  for step in nut_client sensors storage iommu powertop verify; do
    clear_step_done "$step"
  done
  bash "$ROOT_DIR/scripts/post_install.sh"
  printf '%s\n%s\n' "$boot_id" "$mode" > "$checkpoint.tmp"
  mv "$checkpoint.tmp" "$checkpoint"
  echo "Package update completed. Reboot the host, then run: bash $ROOT_DIR/bootstrap.sh"
  exit 0
fi
for step in nut_client sensors storage iommu powertop verify; do
  run_step "$step" "$step configuration" "$ROOT_DIR/scripts/$step.sh"
done
echo "Completed. Reboot if IOMMU configuration changed. Clear the browser cache after GUI repair."
