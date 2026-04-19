#!/usr/bin/env bash
set -Eeuo pipefail

source "${ROOT_DIR}/scripts/common.sh"

apt-get update
bash -c "$(curl -fsSL "$POST_PVE_INSTALL_URL")"
bash -c "$(curl -fsSL "$CPU_GOVERNOR_SCRIPT_URL")"
