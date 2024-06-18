#!/usr/bin/env bash
set -euxo pipefail

blkdev="/dev/vdb"
mnt="/tmp/mnt"
pw=$(genpass)
uuid=$(uuidgen)

# link user and session keyrings so that the key can be found by the kernel
keyctl link @u @s

sfdisk "$blkdev" <<EOF
label: gpt
type=linux, size=1G
type=linux, size=1G
type=linux
EOF

udevadm settle

echo "$pw" | bcachefs format \
    --verbose \
    --encrypted \
    --replicas=2 \
    --uuid "$uuid" \
    --fs_label test-fs \
    "$blkdev"?

udevadm settle

mkdir -p "$mnt"
echo "$pw" | bcachefs mount -v "UUID=$uuid" "$mnt"

keyctl search @u user "bcachefs:$uuid"
