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

#cat << EOF > stage-template/etc/portage/package.mask
#EOF

cat << EOF > stage-template/etc/portage/package.use/sys-fs
# Reduce the dependency on ruby
sys-fs/lvm2 -thin
EOF

ln -sf /usr/portage/profiles/default/linux/amd64/13.0 stage-template/etc/make.profile

cat << EOF > stage-template/etc/portage/make.conf
ACCEPT_KEYWORDS="~amd64"
FEATURES="buildpkg parallel-fetch parallel-install"
USE="-bindist -caps -consolekit systemd"
EOF

cat << EOF > stage-template/var/lib/portage/world
app-editors/vim
app-portage/eix
net-dns/bind-tools
net-misc/dhcpcd
net-nfs/nfs-utils
sys-apps/dbus
sys-apps/gentoo-systemd-integration
sys-apps/iproute2
sys-apps/systemd
sys-boot/grub
sys-boot/os-prober
sys-fs/btrfs-progs
sys-fs/lvm2
sys-fs/squashfs-tools
sys-fs/xfsdump
sys-fs/xfsprogs
sys-kernel/dracut
EOF

tar czf stage-template.tar.gz -C stage-template .
