#!/bin/bash
set -x

I=/root/rootfs.img
M=mountpath

rm -f "$I"
rm -f "$I".xz
truncate -s1G "$I"
mkfs.ext4 "$I"

mkdir -p "$M"
mount -o loop "$I" "$M" || exit 1
function clean_up () {
    umount "$M"
    rm -d "$M"
}
trap 'clean_up' EXIT

unsquashfs -d "$M" -f /root/systemd.squashfs

clean_up
trap - EXIT

e2fsck -f "$I"
resize2fs -M "$I"
xz "$I" && rm -f "$I"
