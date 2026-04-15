#!/usr/bin/env bash

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

  export ROOT_DIR="${root_dir}"
  export UPS_NAME UPS_HOST UPS_USER UPS_PASS ENABLE_IOMMU
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

run_step() {
  local name="$1"
  local script="$2"

  log "$name"
  bash "$script"
}
