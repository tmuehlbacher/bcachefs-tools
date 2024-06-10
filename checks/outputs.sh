#!/usr/bin/env bash
set -euxo pipefail

blkdev="/dev/vdb"
mnt="/tmp/mnt"
uuid=$(uuidgen)

mkdir -p "$mnt"

bcachefs format \
    --verbose \
    --uuid "$uuid" \
    --fs_label test-fs \
    "$blkdev"

mount "$blkdev" "$mnt"

bcachefs show-super "$blkdev" | grep "$uuid"
bcachefs fs usage "$mnt" | grep "$uuid"
