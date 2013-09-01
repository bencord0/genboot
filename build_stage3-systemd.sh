#!/bin/bash
TOPDIR=$(dirname $0)
cd "$TOPDIR"

EMERGE_FLAGS="--buildpkg --update --jobs"
DBUS_DEPS="sys-libs/glibc \
    sys-libs/pam \
    sys-auth/pambase \
    sys-apps/shadow \
    sys-apps/baselayout"

rm -rf "chroot"
mkdir "chroot-prepare" "chroot"
tar xavpf stage-template.tar.gz -C chroot

set -x
emerge $EMERGE_FLAGS --config-root=chroot --root=chroot-prepare \
    world

emerge $EMERGE_FLAGS --usepkgonly --config-root=chroot --root=chroot \
    --oneshot --nodeps $DBUS_DEPS
emerge $EMERGE_FLAGS --usepkgonly --config-root=chroot --root=chroot \
    world

tar cJf stage3-systemd.tar.xz -C chroot .
