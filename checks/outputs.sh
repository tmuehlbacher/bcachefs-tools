#!/usr/bin/env bash
set -euxo pipefail

mountpoint "$MOUNT_POINT"

bcachefs show-super "$BLKDEV"
bcachefs fs usage "$BLKDEV"
