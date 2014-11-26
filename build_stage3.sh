#!/bin/bash
set -x
TOPDIR=$(dirname $0)
cd "$TOPDIR"

EMERGE_FLAGS="--buildpkg --getbinpkg --update --jobs --deep --newuse"
# Host needs to have a expanded toolchain
# We'll also place ebuilds here that (mistakenly) also need users/groups
# installed on the host.
HDEPEND=" \
    dev-lang/swig \
    dev-libs/boost \
    dev-python/m2crypto \
    dev-util/boost-build \
    sys-devel/automake \
    virtual/yacc \
"
DBUS_DEPS1=" \
    sys-libs/glibc \
    sys-libs/cracklib \
    sys-libs/pam \
    sys-apps/shadow \
    sys-apps/baselayout \
"
DBUS_DEPS2=" \
    sys-auth/pambase \
"

rm -rf "chroot-prepare" "chroot"
mkdir "chroot-prepare" "chroot"
tar xavpf stage-template.tar.gz -C chroot-prepare && {
    grep MAKEOPTS /etc/portage/make.conf >> chroot-prepare/etc/portage/make.conf
    grep SYNC /etc/portage/make.conf >> chroot-prepare/etc/portage/make.conf
    grep GENTOO_MIRRORS /etc/portage/make.conf >> chroot-prepare/etc/portage/make.conf
    grep PORTAGE_BINHOST /etc/portage/make.conf >> chroot-prepare/etc/portage/make.conf
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
    --with-bdeps=y --complete-graph=y system sys-apps/systemd
emerge $EMERGE_FLAGS --usepkg --config-root=$ROOT --root=$ROOT \
    --with-bdeps=y --complete-graph=y world

## Step 2: Install all packages and  dependencies from binpkgs
# Make sure that everything needed is inside the ROOT.
export ROOT="${TOPDIR}"/chroot
emerge $EMERGE_FLAGS --usepkgonly --config-root=$ROOT --root=$ROOT \
    --oneshot --nodeps $DBUS_DEPS1
emerge $EMERGE_FLAGS --usepkgonly --config-root=$ROOT --root=$ROOT \
    --oneshot --nodeps $DBUS_DEPS2
emerge $EMERGE_FLAGS --usepkgonly --config-root=$ROOT --root=$ROOT \
    --root-deps --with-bdeps=y --complete-graph=y system sys-apps/systemd
emerge $EMERGE_FLAGS --usepkgonly --config-root=$ROOT --root=$ROOT \
    --root-deps --with-bdeps=y --complete-graph=y world

## Step 3: Configure the system
# Blank out the default root password
sed -i -e '/root/ s/*//' chroot/etc/shadow

# Don't bother looking for other filesystems (esp. SWAP)
echo -n > chroot/etc/fstab

# List mounts correctly
ln -sf /proc/mounts chroot/etc/mtab

# Start systemd services
for svc in networkd resolved timesyncd; do
ln -s "/usr/lib64/systemd/system/systemd-${svc}.service" \
    "chroot/etc/systemd/system/multi-user.target.wants/systemd-${svc}.service"
done
cat << EOF > chroot/etc/systemd/network/dhcp.network
[Match]
Name=e*

[Network]
DHCP=both
EOF
ln -sf /run/systemd/resolve/resolv.conf chroot/etc/resolv.conf

# Autologin
mkdir -p chroot/etc/systemd/system/getty@tty1.service.d
cat << EOF > chroot/etc/systemd/system/getty@tty1.service.d/autologin.conf
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin root --noclear %I 38400 linux
EOF
mkdir -p chroot/etc/systemd/system/getty@hvc0.service.d
cat << EOF > chroot/etc/systemd/system/getty@hvc0.service.d/autologin.conf
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin root --noclear %I 38400 linux
EOF
mkdir -p chroot/etc/systemd/system/serial-getty@ttyS0.service.d
cat << EOF > chroot/etc/systemd/system/serial-getty@ttyS0.service.d/autologin.conf
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin root -s %I 115200,38400,9600 vt102
Type=simple
EOF

# Cloud-init
## Bug: the cloud-*.service units should run after network-online.target
## Bug: cloud-init.service should not need sshd-keygen.service in Gentoo
for svc in config final init; do
ln -s "/usr/lib64/systemd/system/cloud-${svc}.service" \
    "chroot/etc/systemd/system/multi-user.target.wants/cloud-${svc}.service"
ln -s "/usr/lib64/systemd/system/cloud-${svc}.service" \
    "chroot/etc/systemd/system/network-online.target.wants/cloud-${svc}.service"
done
cp cloud.cfg chroot/etc/cloud/cloud.cfg

# Uniqueness
echo > chroot/etc/machine-id

# SSH oddity
chown root chroot/var/empty
ln -s '/usr/lib64/systemd/system/sshd.service' \
    'chroot/etc/systemd/system/multi-user.target.wants/sshd.service'

# Allow NFS client mounts
ln -s '/usr/lib64/systemd/system/rpc-mountd.service' \
    'chroot/etc/systemd/system/multi-user.target.wants/rpc-mountd.service'

rm -f /root/systemd.squashfs || true
rm -f /root/stage3-systemd.tar.xz || true

mksquashfs chroot /root/systemd.squashfs &
tar cJf /root/stage3-systemd.tar.xz -C chroot . &
wait
