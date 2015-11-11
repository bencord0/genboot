#!/bin/bash
set -xe
MAKEOPTS="-j$(grep processor /proc/cpuinfo|wc -l)"

cp config /usr/src/linux/.config

cd /usr/src/linux

# Build a standalone kernel with bundled initramfs
make olddefconfig
make $MAKEOPTS bzImage

cp arch/x86/boot/bzImage /root/vmlinuz
