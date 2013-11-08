#!/bin/bash
set -x
TOPDIR=$(dirname $0)
cd "$TOPDIR"

EMERGE_FLAGS="--buildpkg --update --jobs"
DBUS_DEPS="sys-libs/glibc \
    sys-libs/cracklib \
    sys-libs/pam \
    sys-apps/shadow \
    sys-apps/baselayout"

rm -rf "chroot"
mkdir "chroot-prepare" "chroot"
tar xavpf stage-template.tar.gz -C chroot-prepare
tar xavpf stage-template.tar.gz -C chroot

# Stop when things go wrong
set -ex

# note: dbus's pkg_setup phase needs some files to exist in the chroot

# Building binary packages also installs compile-time dependencies
emerge $EMERGE_FLAGS --usepkg --config-root=chroot-prepare --root=chroot-prepare \
    --oneshot --nodeps $DBUS_DEPS
emerge $EMERGE_FLAGS --usepkg --config-root=chroot-prepare --root=chroot-prepare \
    --oneshot --nodeps sys-auth/pambase
emerge $EMERGE_FLAGS --usepkg --config-root=chroot-prepare --root=chroot-prepare \
    world

# Only install the runtime dependencies
emerge $EMERGE_FLAGS --usepkgonly --config-root=chroot --root=chroot \
    --oneshot --nodeps $DBUS_DEPS
emerge $EMERGE_FLAGS --usepkgonly --config-root=chroot --root=chroot \
    --oneshot --nodeps sys-auth/pambase
emerge $EMERGE_FLAGS --usepkgonly --config-root=chroot --root=chroot \
    world

# Blank out the default root password
sed -i -e '/root/ s/*//' chroot/etc/shadow

# Don't bother looking for other filesystems (esp. SWAP)
echo -n > chroot/etc/fstab

# Start networking on boot
ln -s 'chroot/usr/lib64/systemd/system/dhcpcd.service' \
    'chroot/etc/systemd/system/multi-user.target.wants/dhcpcd.service'

tar cJf /root/stage3-systemd.tar.xz -C chroot .
