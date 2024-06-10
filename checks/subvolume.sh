#!/usr/bin/env bash
set -euxo pipefail

mountpoint "$MOUNT_POINT"

bcachefs subvolume create "$MOUNT_POINT/subvol1"
bcachefs subvolume delete "$MOUNT_POINT/subvol1"

cd "$MOUNT_POINT"

bcachefs subvolume create subvol1
bcachefs subvolume create subvol1/subvol1
bcachefs subvolume create subvol1/subvol2
touch subvol1/file1

bcachefs subvolume delete subvol1/subvol2
bcachefs subvolume delete subvol1
