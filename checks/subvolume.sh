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

touch "$mnt/file1"

bcachefs subvolume create "$mnt/subvol1"
bcachefs subvolume delete "$mnt/subvol1"

(
    cd "$mnt"

    bcachefs subvolume create subvol1
    bcachefs subvolume create subvol1/subvol1
    bcachefs subvolume create subvol1/subvol2
    touch subvol1/file1

    rm subvol1/file1
    bcachefs subvolume delete subvol1/subvol2
    bcachefs subvolume delete subvol1/subvol1
    bcachefs subvolume delete subvol1
)
