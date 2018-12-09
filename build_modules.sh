#!/bin/bash
set -xe
EMERGE_FLAGS="--buildpkg --getbinpkg --update --jobs --deep --newuse"
MAKEOPTS="-j$(nproc)"

emerge $EMERGE_FLAGS --usepkg  sys-kernel/gentoo-sources

latest_kernel=$(eselect kernel list | tail -n 1 | awk '{print $2}')
eselect kernel set "${latest_kernel}"

cp config.nosquash /usr/src/linux/.config
(cd /usr/src/linux; make olddefconfig prepare scripts)

# Copy ZFS source into kernel tree
env EXTRA_ECONF='--with-spl=/usr/src/linux --enable-linux-builtin --with-spl-obj=/usr/src/linux' ebuild /usr/portage/sys-fs/zfs-kmod/zfs-kmod-9999.ebuild clean configure
(cd /var/tmp/portage/sys-fs/zfs-kmod-9999/work/zfs-kmod-9999/ && ./copy-builtin /usr/src/linux)

cp config.nosquash /usr/src/linux/.config

cd /usr/src/linux

KVER="$(make kernelversion)"
make olddefconfig
make kvmconfig
make $MAKEOPTS modules
make modules_install
depmod -av "${KVER}"

# Build a kernel release too (no initramfs)
make $MAKEOPTS tarxz-pkg
cp arch/x86/boot/bzImage /root/vmlinuz.nosquash

cp linux-"${KVER}"-x86.tar.xz /root/linux-image.tar.xz
