#!/bin/bash

DIRS="
    dev
    etc/portage/package.keywords
    etc/portage/package.use
    home
    proc
    root
    sys
    usr/portage
    var/lib/portage
"

for dir in $DIRS; do
    mkdir -p stage-template/$dir
done

ln -sf /usr/portage/profiles/default/linux/amd64/13.0 stage-template/etc/make.profile

cat << EOF > stage-template/etc/portage/make.conf
FEATURES="buildpkg parallel-fetch parallel-install"
MAKEOPTS="-j8"
USE="-bindist -consolekit systemd"
EOF

cat << EOF > stage-template/var/lib/portage/world
app-editors/vim
app-portage/eix
net-dns/bind-tools
net-misc/dhcpcd
sys-apps/dbus
sys-apps/iproute2
sys-apps/systemd
sys-boot/grub
sys-boot/os-prober
sys-fs/btrfs-progs
sys-fs/lvm2
sys-fs/squashfs-tools
sys-kernel/dracut
EOF

tar czf stage-template.tar.gz -C stage-template .
