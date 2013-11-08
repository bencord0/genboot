#!/bin/bash
set -x

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

cat << EOF > stage-template/etc/portage/package.mask
=sys-libs/pam-1.1.6-r2
EOF

cat << EOF > stage-template/etc/portage/package.use/sys-fs
# Reduce the dependency on ruby
sys-fs/lvm2 -thin
EOF

ln -sf /usr/portage/profiles/default/linux/amd64/13.0 stage-template/etc/make.profile

cat << EOF > stage-template/etc/portage/make.conf
ACCEPT_KEYWORDS="~amd64"
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
