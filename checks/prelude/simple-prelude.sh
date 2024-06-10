#!/usr/bin/env bash
set -euxo pipefail

mkdir -p "$MOUNT_POINT"

bcachefs format \
    --verbose \
    --fs_label \
    --uuid="$BCACHEFS_UUID" \
    test-fs "$BLKDEV"

mount "$BLKDEV" "$MOUNT_POINT"
