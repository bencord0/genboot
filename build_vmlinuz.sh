#!/bin/bash
set -x
MAKEOPTS="-j$(grep processor /proc/cpuinfo|wc -l)"

INITRAMFS=/root/initramfs
gunzip -c "${INITRAMFS}" > "${INITRAMFS}.cpio"

cd /usr/src/linux

make $MAKEOPTS targz-pkg

cp "$(make image_name)" /root/vmlinuz
cp linux-"$(make kernelrelease)"-x86.tar.gz /root/linux-image.tar.gz
