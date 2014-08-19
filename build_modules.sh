#!/bin/bash
set -x
EMERGE_FLAGS="--buildpkg --getbinpkg --update --jobs --deep --newuse"
MAKEOPTS="-j$(grep processor /proc/cpuinfo|wc -l)"

echo sys-kernel/aufs-sources >> /etc/portage/package.keywords/sys-kernel
emerge $EMERGE_FLAGS --usepkg  sys-kernel/aufs-sources
cp config.nosquash /usr/src/linux/.config

cd /usr/src/linux

make olddefconfig
make kvmconfig
make $MAKEOPTS modules
make modules_install

# Build a kernel release too (no initramfs)
make $MAKEOPTS tarxz-pkg
cp arch/x86/boot/bzImage /root/vmlinuz.nosquash

cp linux-"$(make kernelrelease)"-x86.tar.xz /root/linux-image.tar.xz
