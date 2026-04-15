#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "${ROOT_DIR}/scripts/common.sh"
load_config "${ROOT_DIR}"

run_step "Post-install configuration" "${ROOT_DIR}/scripts/post_install.sh"
run_step "NUT client configuration" "${ROOT_DIR}/scripts/nut_client.sh"
run_step "Sensors configuration" "${ROOT_DIR}/scripts/sensors.sh"
run_step "IOMMU configuration" "${ROOT_DIR}/scripts/iommu.sh"
run_step "Powertop configuration" "${ROOT_DIR}/scripts/powertop.sh"
run_step "Verification" "${ROOT_DIR}/scripts/verify.sh"

echo
echo "Completed. Reboot recommended."
