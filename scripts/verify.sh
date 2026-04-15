#!/usr/bin/env bash
set -Eeuo pipefail

echo "Checking nut-client:"
systemctl --no-pager --full status nut-client || true

echo
echo "Checking vfio modules:"
lsmod | grep vfio || true

echo
echo "Checking sensors:"
sensors || true

echo
echo "Verification complete."
