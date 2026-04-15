#!/usr/bin/env bash
set -Eeuo pipefail

apt-get update
bash -c "$(curl -fsSL "$POST_PVE_INSTALL_URL")"
bash -c "$(curl -fsSL "$CPU_GOVERNOR_SCRIPT_URL")"
