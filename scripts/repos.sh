#!/usr/bin/env bash
set -Eeuo pipefail
source "${ROOT_DIR}/scripts/common.sh"
command -v pveversion >/dev/null || fail "This script requires a Proxmox VE host."
source /etc/os-release
case "$(pveversion):${VERSION_CODENAME}" in
  pve-manager/8.*:bookworm|pve-manager/9.*:trixie) ;;
  *) fail "Only PVE 8/bookworm and PVE 9/trixie are supported; no major upgrade is performed." ;;
esac
python3 "$ROOT_DIR/scripts/configure_repos.py" "$VERSION_CODENAME"
