#!/usr/bin/env bash
set -Eeuo pipefail

apt-get install -y lm-sensors

if [[ ! -f /root/pve-mod-gui-sensors.sh ]]; then
  curl -fsSL "$PVE_SENSOR_GUI_SCRIPT_URL" -o /root/pve-mod-gui-sensors.sh
  chmod +x /root/pve-mod-gui-sensors.sh
fi

bash /root/pve-mod-gui-sensors.sh install

echo "Run 'sensors-detect' manually if needed for your hardware."
echo "Clear browser cache after the GUI sensors mod."
