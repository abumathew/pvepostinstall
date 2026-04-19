#!/usr/bin/env bash
set -Eeuo pipefail

source "${ROOT_DIR}/scripts/common.sh"

[[ "${ENABLE_IOMMU}" == "true" ]] || exit 0

GRUB_FILE="/etc/default/grub"

if [[ "${IOMMU_CPU_VENDOR:-intel}" == "amd" ]]; then
  IOMMU_ARGS="amd_iommu=on iommu=pt"
else
  IOMMU_ARGS="intel_iommu=on iommu=pt"
fi

if grep -q '^GRUB_CMDLINE_LINUX_DEFAULT=' "$GRUB_FILE"; then
  if ! grep -q 'iommu=pt' "$GRUB_FILE"; then
    sed -i "s/^GRUB_CMDLINE_LINUX_DEFAULT=\"\([^\"]*\)\"/GRUB_CMDLINE_LINUX_DEFAULT=\"\1 ${IOMMU_ARGS}\"/" "$GRUB_FILE"
  fi
else
  echo "GRUB_CMDLINE_LINUX_DEFAULT=\"quiet ${IOMMU_ARGS}\"" >> "$GRUB_FILE"
fi

append_line_if_missing "vfio" /etc/modules
append_line_if_missing "vfio_iommu_type1" /etc/modules
append_line_if_missing "vfio_pci" /etc/modules

update-initramfs -u -k all
update-grub
