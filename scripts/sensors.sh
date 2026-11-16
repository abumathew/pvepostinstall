#!/usr/bin/env bash
set -Eeuo pipefail
source "${ROOT_DIR}/scripts/common.sh"
[[ "${ENABLE_PVE_SENSOR_GUI_MOD:-false}" == true ]] || {
  echo "Sensor GUI mod disabled."
  exit 0
}
apt-get install -y lm-sensors nut-client python3 dmidecode
[[ "$GUI_CPU_MODE" =~ ^[CcAa]$ ]] || fail "GUI_CPU_MODE must be C or a."
[[ "$GUI_ZERO_FANS" =~ ^[YyNn]$ ]] || fail "GUI_ZERO_FANS must be y or n."
[[ "$GUI_TEMP_UNIT" =~ ^[CcFf]$ ]] || fail "GUI_TEMP_UNIT must be C or f."
[[ "$GUI_SYSTEM_INFO" =~ ^[12nN]$ ]] || fail "GUI_SYSTEM_INFO must be 1, 2 or n."
# The vendor patch embeds the UPS address in Perl and shell strings.
[[ "$UPS_NAME" =~ ^[a-zA-Z0-9_.-]+$ && "$UPS_HOST" =~ ^[a-zA-Z0-9_.:-]+$ ]] || fail "Invalid UPS name/host."
js=/usr/share/pve-manager/js/pvemanagerlib.js
pm=/usr/share/perl5/PVE/API2/Nodes.pm
manifest="$STATE_DIR/gui.sha256"
config_hash=$(printf '%s\n' "$GUI_CPU_MODE" "$GUI_ZERO_FANS" "$GUI_TEMP_UNIT" "$GUI_SYSTEM_INFO" "$UPS_NAME" "$UPS_HOST" "$(sha256sum "$ROOT_DIR/vendor/pve-mod-gui-sensors.sh")" | sha256sum)
config_hash="${config_hash%% *}"
if [[ -f "$manifest" && -f "$STATE_DIR/gui.config" && $(cat "$STATE_DIR/gui.config") == "$config_hash" ]] && sha256sum --status -c "$manifest"; then
  echo "Sensor/UPS GUI patch is intact."
  exit 0
fi
work=$(mktemp -d)
# apt's download sandbox must be able to access its working directory.
chmod 755 "$work"
trap 'rm -rf "$work"' EXIT
for target in "$js" "$pm"; do
  package=$(dpkg-query -S "$target")
  package=${package%%: /*}
  version=$(dpkg-query -W -f='${Version}' "$package")
  mkdir -p "$work/download"
  (cd "$work/download"; apt-get download "$package=$version")
  for deb in "$work/download/"*.deb; do
    dpkg-deb -x "$deb" "$work/clean"
    rm "$deb"
  done
done
# Work on pristine files from the EXACT installed packages, never old .bak files.
export PVE_MANAGER_LIB_JS_FILE="$work/clean$js"
export NODES_PM_FILE="$work/clean$pm"
export PVE_MOD_AUTOMATED=true PVE_MOD_STAGING=true
export PVE_MOD_BACKUP_DIR="$work/backups"
export PVE_MOD_TMPDIR="$work"
mkdir -p "$PVE_MOD_BACKUP_DIR"
upsc "${UPS_NAME}@${UPS_HOST}" > "$work/ups.txt"
grep -qE '^(device|ups)\.model:' "$work/ups.txt" || fail "UPS model unavailable; refusing to silently omit UPS display."
[[ -f "$PVE_MANAGER_LIB_JS_FILE" && -f "$NODES_PM_FILE" ]] || fail "Package extraction did not provide GUI files."
bash "$ROOT_DIR/vendor/pve-mod-gui-sensors.sh" install
grep -Fq '$res->{upsc}' "$NODES_PM_FILE"
grep -q "itemId: 'upsc'" "$PVE_MANAGER_LIB_JS_FILE"
perl -T -c "$NODES_PM_FILE"
backup=$(mktemp -d "$STATE_DIR/gui-backup.XXXXXXXX")
cp -a "$js" "$backup/pvemanagerlib.js"
cp -a "$pm" "$backup/Nodes.pm"
rollback() {
  cp -a "$backup/pvemanagerlib.js" "$js"
  cp -a "$backup/Nodes.pm" "$pm"
  systemctl restart pveproxy || true
}
trap 'rollback; rm -rf "$work"' ERR
install -m 644 "$PVE_MANAGER_LIB_JS_FILE" "$js"
install -m 644 "$NODES_PM_FILE" "$pm"
systemctl restart pveproxy
sha256sum "$js" "$pm" > "$manifest.tmp"
mv "$manifest.tmp" "$manifest"
printf '%s\n' "$config_hash" > "$STATE_DIR/gui.config"
trap - ERR
echo "Sensor/UPS GUI restored. Clear your browser cache. Backup: $backup"
