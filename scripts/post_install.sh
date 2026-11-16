#!/usr/bin/env bash
set -Eeuo pipefail
source "${ROOT_DIR}/scripts/common.sh"
apt-get update
apt-get dist-upgrade -y
