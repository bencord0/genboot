#!/bin/bash
set -x
TOPDIR=$(dirname $0)
cd "$TOPDIR"

EMERGE_FLAGS="--buildpkg --getbinpkg --update --jobs --deep --newuse"
# Host needs to have a expanded toolchain
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

# Build some host dependencies
emerge $EMERGE_FLAGS --usepkg --oneshot \
    $HDEPEND
# Building binary packages also installs compile-time dependencies
export ROOT="${TOPDIR}"/chroot-prepare
emerge $EMERGE_FLAGS --usepkg --config-root=$ROOT --root=$ROOT \
    --oneshot --nodeps $DBUS_DEPS1
emerge $EMERGE_FLAGS --usepkg --config-root=$ROOT --root=$ROOT \
    --oneshot --nodeps $DBUS_DEPS2
# Check that we have binaries. Don't use --update
for dep in $DBUS_DEPS1 $DBUS_DEPS2; do
    eix --quiet --binary $dep || \
    emerge --ignore-default-opts --buildpkg --getbinpkg --jobs \
        --config-root=$ROOT --root=$ROOT --oneshot --nodeps \
        $dep
done
emerge $EMERGE_FLAGS --usepkg --config-root=$ROOT --root=$ROOT \
    --with-bdeps=y --complete-graph=y system
emerge $EMERGE_FLAGS --usepkg --config-root=$ROOT --root=$ROOT \
    --with-bdeps=y --complete-graph=y world

# Only install the runtime dependencies
export ROOT="${TOPDIR}"/chroot
emerge $EMERGE_FLAGS --usepkgonly --config-root=$ROOT --root=$ROOT \
    --oneshot --nodeps $DBUS_DEPS1
emerge $EMERGE_FLAGS --usepkgonly --config-root=$ROOT --root=$ROOT \
    --oneshot --nodeps $DBUS_DEPS2
emerge $EMERGE_FLAGS --usepkgonly --config-root=$ROOT --root=$ROOT \
    --root-deps --with-bdeps=y --complete-graph=y system
emerge $EMERGE_FLAGS --usepkgonly --config-root=$ROOT --root=$ROOT \
    --root-deps=rdeps --with-bdeps=n --complete-graph=y world

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
for svc in config final init; do
ln -s "/usr/lib64/systemd/system/cloud-${svc}.service" \
    "chroot/etc/systemd/system/multi-user.target.wants/cloud-${svc}.service"
done

# Uniqueness
echo > chroot/etc/machine-id

# SSH oddity
chown root chroot/var/empty
ln -s '/usr/lib64/systemd/system/sshd.service' \
    'chroot/etc/systemd/system/multi-user.target.wants/sshd.service'

rm -f /root/systemd.squashfs || true
rm -f /root/stage3-systemd.tar.xz || true

mksquashfs chroot /root/systemd.squashfs &
tar cJf /root/stage3-systemd.tar.xz -C chroot . &
wait
