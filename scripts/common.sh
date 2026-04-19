#!/usr/bin/env bash

STATE_DIR="/var/lib/proxmox-bootstrap-state"

log() {
  echo
  echo "==== $* ===="
}

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

require_root() {
  [[ "${EUID}" -eq 0 ]] || fail "Run this as root."
}

load_config() {
  local root_dir="$1"

  require_root

  mkdir -p "$STATE_DIR"

  [[ -f "${root_dir}/config/defaults.env" ]] && source "${root_dir}/config/defaults.env"

  if [[ -f "${root_dir}/.env" ]]; then
    source "${root_dir}/.env"
  else
    fail ".env file not found. Copy .env.example to .env and fill it out."
  fi

  : "${UPS_NAME:?Missing UPS_NAME}"
  : "${UPS_HOST:?Missing UPS_HOST}"
  : "${UPS_USER:?Missing UPS_USER}"
  : "${UPS_PASS:?Missing UPS_PASS}"
  : "${ENABLE_IOMMU:?Missing ENABLE_IOMMU}"

  : "${SMB1_NAME:?Missing SMB1_NAME}"
  : "${SMB1_SERVER:?Missing SMB1_SERVER}"
  : "${SMB1_SHARE:?Missing SMB1_SHARE}"
  : "${SMB2_NAME:?Missing SMB2_NAME}"
  : "${SMB2_SERVER:?Missing SMB2_SERVER}"
  : "${SMB2_SHARE:?Missing SMB2_SHARE}"
  : "${SMB_USER:?Missing SMB_USER}"
  : "${SMB_PASS:?Missing SMB_PASS}"

  export ROOT_DIR="${root_dir}"
  export STATE_DIR

  export UPS_NAME UPS_HOST UPS_USER UPS_PASS ENABLE_IOMMU
  export SMB1_NAME SMB1_SERVER SMB1_SHARE
  export SMB2_NAME SMB2_SERVER SMB2_SHARE
  export SMB_USER SMB_PASS

  export POST_PVE_INSTALL_URL CPU_GOVERNOR_SCRIPT_URL PVE_SENSOR_GUI_SCRIPT_URL IOMMU_CPU_VENDOR
}
backup_file() {
  local file="$1"
  [[ -f "$file" && ! -f "${file}.bak" ]] && cp -a "$file" "${file}.bak"
}

append_line_if_missing() {
  local line="$1"
  local file="$2"
  touch "$file"
  grep -Fxq "$line" "$file" || echo "$line" >> "$file"
}

render_template() {
  local src="$1"
  local dest="$2"
  envsubst < "$src" > "$dest"
}

step_done_file() {
  local step_id="$1"
  echo "${STATE_DIR}/${step_id}.done"
}

is_step_done() {
  local step_id="$1"
  [[ -f "$(step_done_file "$step_id")" ]]
}

mark_step_done() {
  local step_id="$1"
  touch "$(step_done_file "$step_id")"
}

clear_step_done() {
  local step_id="$1"
  rm -f "$(step_done_file "$step_id")"
}

run_step() {
  local step_id="$1"
  local name="$2"
  local script="$3"

  if is_step_done "$step_id"; then
    log "${name} (already completed, skipping)"
    return
  fi

  log "${name}"
  if bash "$script"; then
    mark_step_done "$step_id"
    echo "Marked ${step_id} as completed"
  else
    echo "Step ${step_id} failed"
    exit 1
  fi
}

reset_state() {
  rm -rf "$STATE_DIR"
  mkdir -p "$STATE_DIR"
}