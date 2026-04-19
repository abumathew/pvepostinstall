#!/usr/bin/env bash
set -Eeuo pipefail

source "${ROOT_DIR}/scripts/common.sh"

assert_writable() {
  local path="$1"
  local testfile="${path}/.bootstrap-write-test"

  touch "$testfile"
  rm -f "$testfile"
}

storage_exists() {
  local name="$1"
  grep -qE "^[[:space:]]*cifs:[[:space:]]*${name}$" /etc/pve/storage.cfg 2>/dev/null
}

add_cifs_storage() {
  local name="$1"
  local server="$2"
  local share="$3"
  local content="$4"
  local path="/mnt/pve/${name}"

  if storage_exists "$name"; then
    echo "Storage ${name} already exists, skipping"
    return
  fi

  if [[ -d "$path" ]]; then
    assert_writable "$path"
  fi

  pvesm add cifs "$name" \
    --server "$server" \
    --share "$share" \
    --username "$SMB_USER" \
    --password "$SMB_PASS" \
    --content "$content" \
    --nodes "$(hostname)"
}

add_cifs_storage "$SMB1_NAME" "$SMB1_SERVER" "$SMB1_SHARE" "images,iso"
add_cifs_storage "$SMB2_NAME" "$SMB2_SERVER" "$SMB2_SHARE" "backup"