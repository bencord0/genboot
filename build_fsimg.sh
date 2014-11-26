#!/bin/bash
set -x

I=/root/rootfs.img
M=mountpath

rm -f "$I"
rm -f "$I".xz
truncate -s2G "$I"
mkfs.ext4 "$I"

mkdir -p "$M"

# In some container environments, a loop device might not be available.
ls /dev/loop0 || mknod /dev/loop0 b 7 0 || {
    echo "Unable to use loop devices."
    echo "Skipping rootfs.img."
    exit 0
}

mount -o loop "$I" "$M" || exit 1
function clean_up () {
    umount -l "$M"
    rm -d "$M"
}
trap 'clean_up' EXIT

unsquashfs -d "$M" -f /root/systemd.squashfs

clean_up
trap - EXIT

e2fsck -f "$I"
resize2fs -M "$I"
xz "$I" && rm -f "$I"
