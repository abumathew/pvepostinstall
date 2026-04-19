#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "${ROOT_DIR}/scripts/common.sh"
load_config "${ROOT_DIR}"

case "${1:-}" in
  --reset)
    reset_state
    echo "State reset complete."
    ;;
esac

run_step "post_install" "Post-install configuration" "${ROOT_DIR}/scripts/post_install.sh"
run_step "nut_client" "NUT client configuration" "${ROOT_DIR}/scripts/nut_client.sh"
run_step "sensors" "Sensors configuration" "${ROOT_DIR}/scripts/sensors.sh"
run_step "storage" "Storage configuration" "${ROOT_DIR}/scripts/storage.sh"
run_step "iommu" "IOMMU configuration" "${ROOT_DIR}/scripts/iommu.sh"
run_step "powertop" "Powertop configuration" "${ROOT_DIR}/scripts/powertop.sh"
run_step "verify" "Verification" "${ROOT_DIR}/scripts/verify.sh"

echo
echo "Completed. Reboot recommended."