#!/bin/bash
set -x
MAKEOPTS="-j$(grep processor /proc/cpuinfo|wc -l)"
INITRAMFS=/root/initramfs

gunzip -c "${INITRAMFS}" > "${INITRAMFS}.cpio"
cp config /usr/src/linux/.config

cd /usr/src/linux

make $MAKEOPTS targz-pkg

cp "$(make image_name)" /root/vmlinuz
