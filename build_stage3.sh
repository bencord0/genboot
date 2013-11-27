#!/bin/bash
set -x
TOPDIR=$(dirname $0)
cd "$TOPDIR"

EMERGE_FLAGS="--buildpkg --getbinpkg --update --jobs --deep --newuse"
# sys-libs/pam needs yacc to compile, but is not needed in the final rootfs
HDEPEND=" \
    virtual/yacc \
"
DBUS_DEPS="sys-libs/glibc \
    sys-libs/cracklib \
    sys-libs/pam \
    sys-apps/shadow \
    sys-apps/baselayout \
"
rm -rf "chroot"
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

# note: dbus's pkg_setup phase needs some files to exist in the chroot
# note: pam, an install dependency of dbus, has a compile dependency on yacc
emerge $EMERGE_FLAGS --usepkg \
    $HDEPEND
# Building binary packages also installs compile-time dependencies
export EPREFIX="${TOPDIR}"/chroot-prepare
emerge $EMERGE_FLAGS --usepkg --config-root=$EPREFIX --root=$EPREFIX \
    --oneshot --nodeps $DBUS_DEPS
emerge $EMERGE_FLAGS --usepkg --config-root=$EPREFIX --root=$EPREFIX \
    --oneshot --nodeps sys-auth/pambase
emerge $EMERGE_FLAGS --usepkg --config-root=$EPREFIX --root=$EPREFIX \
    --with-bdeps=y --complete-graph=y world

# Only install the runtime dependencies
export EPREFIX="${TOPDIR}"/chroot
emerge $EMERGE_FLAGS --usepkgonly --config-root=$EPREFIX --root=$EPREFIX \
    --oneshot --nodeps $DBUS_DEPS
emerge $EMERGE_FLAGS --usepkgonly --config-root=$EPREFIX --root=$EPREFIX \
    --oneshot --nodeps sys-auth/pambase
emerge $EMERGE_FLAGS --usepkgonly --config-root=$EPREFIX --root=$EPREFIX \
    world

# Blank out the default root password
sed -i -e '/root/ s/*//' chroot/etc/shadow

# Don't bother looking for other filesystems (esp. SWAP)
echo -n > chroot/etc/fstab

# List mounts correctly
ln -sf /proc/mounts chroot/etc/mtab

# Start networking on boot
ln -s 'chroot/usr/lib64/systemd/system/dhcpcd.service' \
    'chroot/etc/systemd/system/multi-user.target.wants/dhcpcd.service'

# Autologin
mkdir -p chroot/etc/systemd/system/getty@tty1.service.d
cat << EOF > chroot/etc/systemd/system/getty@tty1.service.d/autologin.conf
[Service]
ExecStart=
ExecStart=-/usr/bin/agetty --autologin root --noclear %I 38400 linux
EOF
mkdir -p chroot/etc/systemd/system/serial-getty@ttyS0.service.d
cat << EOF > chroot/etc/systemd/system/serial-getty@ttyS0.service.d/autologin.conf
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin root -s %I 115200,38400,9600 vt102
Type=simple
EOF

# Cloud-init
cp cloud-init-gist chroot/etc/local.d/cloud-init
chmod +x chroot/etc/local.d/cloud-init

tar cJf /root/stage3-systemd.tar.xz -C chroot .
