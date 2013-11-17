#!/bin/bash
set -x
MAKEOPTS="-j$(grep processor /proc/cpuinfo|wc -l)"
EMERGE_FLAGS="--buildpkg --getbinpkg --update --jobs --deep --newuse"

emerge $EMERGE_FLAGS --usepkg  sys-kernel/aufs-sources

cd /usr/src/linux

zcat /proc/config.gz > .config
make olddefconfig
make $MAKEOPTS targz-pkg

cd /
tar xzvf /usr/src/linux/linux*.tar.gz

depmod
cp /boot/vmlinuz* /root/vmlinuz
