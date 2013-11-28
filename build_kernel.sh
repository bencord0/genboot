#!/bin/bash
set -x
MAKEOPTS="-j$(grep processor /proc/cpuinfo|wc -l)"
EMERGE_FLAGS="--buildpkg --getbinpkg --update --jobs --deep --newuse"

emerge $EMERGE_FLAGS --usepkg  sys-kernel/aufs-sources

cd /usr/src/linux

zcat /proc/config.gz > .config
make olddefconfig
make kvmconfig
make $MAKEOPTS targz-pkg

cp "$(make image_name)" /root/vmlinuz
cp linux-"$(make kernelrelease)"-x86.tar.gz /root/linux-image.tar.gz
