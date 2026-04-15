#!/usr/bin/env bash
set -Eeuo pipefail

add_cifs_storage() {
  local name="$1"
  local server="$2"
  local share="$3"
  local content="$4"

  if pvesm status | grep -q "^${name} "; then
    echo "Storage ${name} already exists, skipping"
    return
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
