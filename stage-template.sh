#!/bin/bash
set -x

DIRS="
    dev
    etc/portage/package.keywords
    etc/portage/package.use
    home
    mnt/gentoo
    proc
    root
    sys
    tmp
    usr/portage
    var/lib/portage
"

for dir in $DIRS; do
    mkdir -p stage-template/$dir
done

cat << EOF > stage-template/etc/portage/package.keywords/app-emulation
app-emulation/cloud-init
EOF

cat << EOF > stage-templates/etc/portage/package.keywords/app-portage
app-portage/layman
EOF

cat << EOF > stage-template/etc/portage/package.keywords/dev-python
dev-python/jsonpatch
dev-python/jsonpointer
dev-python/oauth
EOF

cat << EOF > stage-template/etc/portage/package.keywords/sys-apps
sys-apps/portage
EOF

cat << EOF > stage-template/etc/portage/package.keywords/sys-boot
sys-boot/os-prober
EOF

cat << EOF > stage-template/etc/portage/package.keywords/sys-kernel
sys-kernel/dracut
EOF

cat << EOF > stage-template/etc/portage/package.mask
# Fails to configure, being replaced by npth in gnupg-2.1
# Revert to gnupg-1 in the meantime
~app-crypt/gnupg-2.0.25
~app-crypt/gnupg-2.0.26
dev-libs/pth
# udev is replaced by systemd
sys-fs/udev
EOF

cat << EOF > stage-template/etc/portage/package.use/dev-lang
dev-lang/python sqlite
EOF

cat << EOF > stage-template/etc/portage/package.use/sys-boot
sys-boot/grub device-mapper
EOF

ln -sf /usr/portage/profiles/default/linux/amd64/13.0 stage-template/etc/make.profile

cat << EOF > stage-template/etc/portage/make.conf
ACCEPT_KEYWORDS="amd64"
EMERGE_DEFAULT_OPTS="--usepkg"
FEATURES="buildpkg parallel-fetch parallel-install"
USE="-consolekit systemd"
EOF

mkdir -p stage-template/etc/portage/repos.d
cat << EOF > stage-template/etc/portage/repos.d/gentoo.conf
[DEFAULT]
main-repo = gentoo

[gentoo]
location = /usr/portage
sync-type = rsync
sync-uri = rsync://rsync.gentoo.org/gentoo-portage
auto-sync = yes
EOF

cat << EOF > stage-template/var/lib/portage/world
app-admin/ansible
app-admin/sudo
app-editors/vim
app-emulation/cloud-init
app-portage/eix
app-portage/gentoolkit
app-portage/layman
app-portage/portage-utils
dev-python/virtualenv
dev-vcs/git
mail-mta/opensmtpd
net-dns/bind-tools
net-misc/bridge-utils
net-misc/curl
net-fs/nfs-utils
net-wireless/wpa_supplicant
sys-apps/dbus
sys-apps/gentoo-systemd-integration
sys-apps/iproute2
sys-apps/pciutils
sys-apps/systemd
sys-apps/usbutils
sys-boot/grub
sys-boot/os-prober
sys-boot/syslinux
sys-fs/btrfs-progs
sys-fs/dosfstools
sys-fs/lvm2
sys-fs/squashfs-tools
sys-fs/xfsdump
sys-fs/xfsprogs
sys-kernel/dracut
sys-kernel/linux-firmware
sys-process/htop
EOF

tar czf stage-template.tar.gz -C stage-template .
