#!/bin/bash
set -xe
TOPDIR=$(dirname $0)
cd "$TOPDIR"

EMERGE_FLAGS="--buildpkg --getbinpkg --update --jobs --deep --newuse"
# Host needs to have a expanded toolchain
# We'll also place ebuilds here that (mistakenly) also need users/groups
# installed on the host.
HDEPEND=" \
    dev-libs/boost \
    dev-util/boost-build \
    sys-devel/automake \
    virtual/yacc \
"
DBUS_DEPS1=" \
    sys-apps/baselayout \
    sys-libs/glibc \
    sys-libs/cracklib \
    sys-libs/pam \
    sys-apps/shadow \
"
DBUS_DEPS2=" \
    sys-auth/pambase \
"

rm -rf "chroot-prepare" "chroot"
mkdir "chroot-prepare" "chroot"
tar xavpf stage-template.tar.gz -C chroot-prepare && {
## Local chroot-prepare modifications go here
## The chroot directory will remian pristine

# parallelism bug in make-4.1?
#    grep MAKEOPTS /etc/portage/make.conf >> chroot-prepare/etc/portage/make.conf
    grep PORTAGE_BINHOST /etc/portage/make.conf >> chroot-prepare/etc/portage/make.conf || true

    cp /etc/portage/repos.conf/gentoo.conf chroot-prepare/etc/portage/repos.conf/gentoo.conf
}
tar xavpf stage-template.tar.gz -C chroot

# Stop when things go wrong
set -ex

## Step 0: Update the host
emerge $EMERGE_FLAGS --usepkg --oneshot \
    $HDEPEND

# BUG: sys-apps/man-db fails to 'chown man' in ROOT if the 'man'
# user is not available in the host.
# Note: do not use --update, the package might be installed, but
# the user might not be created if this bug has been encountered.
getent passwd man > /dev/null || \
emerge --buildpkg --getbinpkg --usepkg --oneshot \
    sys-apps/man-db

## Note 1:Step 1 and 2 can be merged when HDEPEND is implemented.
## Note 2: --oneshot DBUS_DEPS can be removed when portage learns
##    how to handle @system dependencies properly when ROOT is
##    an empty directory. This is not tested upstream since dbus
##    is not part of the system set when using openrc.

## Step 1: Build all packages and dependencies.
# Building binary packages also installs compile-time dependencies
# to the host system.
export ROOT="${TOPDIR}"/chroot-prepare
emerge $EMERGE_FLAGS --usepkg --config-root=$ROOT --root=$ROOT \
    --oneshot --nodeps $DBUS_DEPS1
emerge $EMERGE_FLAGS --usepkg --config-root=$ROOT --root=$ROOT \
    --oneshot --nodeps $DBUS_DEPS2
for dep in $DBUS_DEPS1 $DBUS_DEPS2; do
    eix --quiet --binary $dep || \
    emerge --ignore-default-opts --buildpkg --getbinpkg --jobs \
        --config-root=$ROOT --root=$ROOT --oneshot --nodeps \
        $dep
done
emerge $EMERGE_FLAGS --usepkg --config-root=$ROOT --root=$ROOT \
    --with-bdeps=y --complete-graph=y --backtrack=30 system sys-apps/systemd
emerge $EMERGE_FLAGS --usepkg --config-root=$ROOT --root=$ROOT \
    --with-bdeps=y --complete-graph=y --backtrack=30  world

## Step 2: Install all packages and  dependencies from binpkgs
# Make sure that everything needed for 'emerge' is inside the ROOT.
export ROOT="${TOPDIR}"/chroot
emerge $EMERGE_FLAGS --usepkgonly --config-root=$ROOT --root=$ROOT \
    --oneshot --nodeps $DBUS_DEPS1
emerge $EMERGE_FLAGS --usepkgonly --config-root=$ROOT --root=$ROOT \
    --oneshot --nodeps $DBUS_DEPS2
emerge $EMERGE_FLAGS --usepkgonly --config-root=$ROOT --root=$ROOT \
    --root-deps --with-bdeps=n --complete-graph=y --backtrack=30 system

## Step 3: Install everything, in place, quickly.
# --emptytree is used, replacing --update to force a reinstall
# of all packages to pickup portage installed users and groups.
systemd-nspawn --bind /usr/portage --bind /var/lib/portage/packages \
    -D $ROOT emerge --emptytree --usepkgonly --jobs \
    --with-bdeps=n --complete-graph=y world

# shellcheck: this is safe, even if $ROOT is unset
rm -d $ROOT/var/tmp/portage/._unmerge_
