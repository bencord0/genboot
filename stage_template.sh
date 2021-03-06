#!/bin/bash
set -xe

DIRS="
    dev
    etc/portage/package.keywords
    etc/portage/package.use
    etc/portage/postsync.d
    etc/portage/profile
    etc/portage/repos.conf
    home
    lib32
    lib64
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

ln -sf lib64 stage-template/lib

cat << EOF > stage-template/etc/locale.gen
en_GB.UTF-8 UTF-8
en_US.UTF-8 UTF-8
EOF

cat << EOF > stage-template/etc/portage/package.keywords/net-libs
net-libs/libasr
EOF

cat << EOF > stage-template/etc/portage/package.keywords/net-misc
net-misc/casync
EOF

cat << EOF > stage-template/etc/portage/package.keywords/sys-boot
sys-boot/os-prober
EOF

cat << EOF > stage-template/etc/portage/package.keywords/sys-fs
sys-fs/zfs **
sys-fs/zfs-kmod **
EOF

cat << EOF > stage-template/etc/portage/package.keywords/sys-kernel
sys-kernel/dracut
sys-kernel/spl **
EOF

cat << EOF > stage-template/etc/portage/package.mask
# udev is replaced by systemd
sys-fs/udev
EOF

cat << EOF > stage-template/etc/portage/profile/package.use.mask
sys-fs/zfs -kernel-builtin
EOF

cat << EOF > stage-template/etc/portage/package.use/dev-lang
dev-lang/python sqlite
EOF

cat << EOF > stage-template/etc/portage/package.use/dev-python
dev-python/netaddr -cli
EOF

cat << EOF > stage-template/etc/portage/package.use/net-firewall
net-firewall/iptables conntrack netlink
EOF

cat << EOF > stage-template/etc/portage/package.use/sys-apps
sys-apps/systemd cryptsetup curl gcrypt gnuefi importd lzma
EOF

cat << EOF > stage-template/etc/portage/package.use/sys-boot
sys-boot/grub device-mapper mount
EOF

cat << EOF > stage-template/etc/portage/package.use/sys-fs
sys-fs/zfs kernel-builtin
EOF

ln -sf /usr/portage/profiles/default/linux/amd64/17.0/systemd stage-template/etc/make.profile

cat << EOF > stage-template/etc/portage/make.conf
ACCEPT_KEYWORDS="amd64"
EMERGE_DEFAULT_OPTS="--usepkg --autounmask-backtrack=y"
FEATURES="buildpkg binpkg-multi-instance parallel-fetch parallel-install userfetch userpriv usersync"
PORTAGE_RO_DISTDIRS="/usr/portage/distfiles"
DISTDIR="/var/lib/portage/distfiles/"
PKGDIR="/var/lib/portage/packages/"
RPMDIR="/var/lib/portage/rpms/"
USE="-consolekit systemd"
EOF

cp /usr/share/portage/config/repos.conf stage-template/etc/portage/repos.conf/gentoo.conf

cat << EOF > stage-template/etc/portage/postsync.d/eix-update
#!/bin/bash
[ -x /usr/bin/eix-update ] && /usr/bin/eix-update
EOF
chmod +x stage-template/etc/portage/postsync.d/eix-update

cat << EOF > stage-template/var/lib/portage/world
app-admin/sudo
app-admin/sysstat
app-editors/vim
app-emulation/cloud-init
app-portage/eix
app-portage/gentoolkit
app-portage/layman
app-portage/portage-utils
dev-python/virtualenv
dev-util/pkgconfig
dev-vcs/git
mail-mta/nullmailer
net-dns/bind-tools
net-misc/bridge-utils
net-misc/casync
net-misc/curl
net-fs/nfs-utils
net-wireless/wpa_supplicant
sys-apps/dmidecode
sys-apps/flashrom
sys-apps/gentoo-systemd-integration
sys-apps/pciutils
sys-apps/systemd
sys-apps/usbutils
sys-boot/grub
sys-boot/os-prober
sys-boot/syslinux
sys-devel/bc
sys-fs/cryptsetup
sys-fs/lvm2
sys-fs/squashfs-tools
sys-fs/zfs
sys-kernel/dracut
sys-kernel/linux-firmware
sys-process/htop
EOF

cat << EOF > stage-template/etc/nsswitch.conf
passwd:      mymachines files
group:       mymachines files
shadow:      files
hosts:       files resolve mymachines myhostname
networks:    files dns
services:    db files
protocols:   db files
rpc:         db files
ethers:      db files
netmasks:    files
netgroup:    files
bootparams:  files
automount:   files
aliases:     files
EOF

tar czf stage-template.tar.gz -C stage-template .
