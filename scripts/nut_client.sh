#!/usr/bin/env bash
set -Eeuo pipefail

source "${ROOT_DIR}/scripts/common.sh"

apt-get install -y nut-client gettext-base

backup_file /etc/nut/nut.conf
backup_file /etc/nut/upsmon.conf
backup_file /etc/nut/upssched.conf

render_template "${ROOT_DIR}/templates/nut.conf.tpl" /etc/nut/nut.conf
render_template "${ROOT_DIR}/templates/upsmon.conf.tpl" /etc/nut/upsmon.conf
render_template "${ROOT_DIR}/templates/upssched.conf.tpl" /etc/nut/upssched.conf

mkdir -p /etc/nut/upssched
render_template "${ROOT_DIR}/templates/upssched-cmd.tpl" /etc/nut/upssched-cmd

chmod +x /etc/nut/upssched-cmd

systemctl enable nut-client || true
systemctl restart nut-client