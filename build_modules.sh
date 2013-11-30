#!/bin/bash
set -x
MAKEOPTS="-j$(grep processor /proc/cpuinfo|wc -l)"
EMERGE_FLAGS="--buildpkg --getbinpkg --update --jobs --deep --newuse"

emerge $EMERGE_FLAGS --usepkg  sys-kernel/aufs-sources
cp config /usr/src/linux/.config

cd /usr/src/linux

make olddefconfig
make kvmconfig
make $MAKEOPTS modules modules_install

