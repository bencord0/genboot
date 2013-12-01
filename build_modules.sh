#!/bin/bash
set -x
EMERGE_FLAGS="--buildpkg --getbinpkg --update --jobs --deep --newuse"

emerge $EMERGE_FLAGS --usepkg  sys-kernel/aufs-sources
test -f /usr/src/linux/.config || cp config /usr/src/linux/.config

cd /usr/src/linux

make olddefconfig
make kvmconfig
make modules
make modules_install
