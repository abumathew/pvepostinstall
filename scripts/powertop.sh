#!/usr/bin/env bash
set -Eeuo pipefail

apt-get install -y powertop gettext-base

render_template "${ROOT_DIR}/templates/powertop-autotune.service.tpl" /etc/systemd/system/powertop-autotune.service

systemctl daemon-reload
systemctl enable --now powertop-autotune.service
