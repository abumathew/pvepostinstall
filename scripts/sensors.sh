#!/usr/bin/env bash
set -Eeuo pipefail

source "${ROOT_DIR}/scripts/common.sh"

apt-get install -y lm-sensors

echo "lm-sensors installed."

if [[ "${ENABLE_PVE_SENSOR_GUI_MOD:-false}" == "true" ]]; then
  LOCAL_SENSOR_MOD="${ROOT_DIR}/vendor/pve-mod-gui-sensors.sh"

  if [[ -f "$LOCAL_SENSOR_MOD" ]]; then
    chmod +x "$LOCAL_SENSOR_MOD"
    bash "$LOCAL_SENSOR_MOD"
  else
    echo "WARNING: Sensor GUI mod enabled, but file not found: $LOCAL_SENSOR_MOD"
    exit 1
  fi
else
  echo "PVE sensor GUI mod disabled. Skipping third-party GUI patch."
fi

echo "Run 'sensors-detect' manually if needed for your hardware."
echo "Clear browser cache after applying the GUI sensors mod."