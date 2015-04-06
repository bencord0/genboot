#!/bin/bash

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
mkdir -p "chroot/etc/systemd/system/network-online.target.wants"
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
