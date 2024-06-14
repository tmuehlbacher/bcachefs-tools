#!/usr/bin/env bash
set -euxo pipefail

blkdev="/dev/vdb"
mnt="/tmp/mnt"
uuid=$(uuidgen)

bcachefs format \
    --verbose \
    --uuid "$uuid" \
    --fs_label test-fs \
    "$blkdev"

udevadm settle

mkdir -p "$mnt"
mount "$blkdev" "$mnt"

bcachefs show-super "$blkdev" | grep -i "external.*$uuid"
bcachefs fs usage "$mnt" | grep "$uuid"
