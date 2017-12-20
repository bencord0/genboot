#!/bin/bash
set -xe

I=/root/rootfs.img

rm -f "$I"
rm -f "$I".xz

# Create an ext4 filesystem from a directory
mkfs.ext4 -v -d chroot "$I" 2G

# Minimize the filesystem
e2fsck -fy "$I"
resize2fs -M "$I"

# Compress the filesystem
xz "$I" && rm -f "$I"
