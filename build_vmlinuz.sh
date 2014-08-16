#!/bin/bash
set -x
MAKEOPTS="-j$(grep processor /proc/cpuinfo|wc -l)"

cp config /usr/src/linux/.config

cd /usr/src/linux

# Build a standalone kernel with bundled initramfs
make $MAKEOPTS bzImage

cp arch/x86/boot/bzImage /root/vmlinuz
