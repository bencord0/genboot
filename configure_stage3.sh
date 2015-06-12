#!/bin/bash

## Step 3: Configure the system
# Blank out the default root password
sed -i -e '/root/ s/*//' chroot/etc/shadow

# Don't bother looking for other filesystems (esp. SWAP)
echo -n > chroot/etc/fstab

# List mounts correctly
ln -sf /proc/mounts chroot/etc/mtab

# Create systemd admin directories
mkdir -p \
    "chroot/etc/systemd/system/multi-user.target.wants" \
    "chroot/etc/systemd/system/remote-fs.target.wants" \


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

# Cloud-init
## Bug: cloud-init.service should not need sshd-keygen.service in Gentoo
for svc in config final init init-local; do
ln -s "/usr/lib64/systemd/system/cloud-${svc}.service" \
    "chroot/etc/systemd/system/multi-user.target.wants/cloud-${svc}.service"
done
cp cloud.cfg chroot/etc/cloud/cloud.cfg
cp 05_logging.cfg chroot/etc/cloud/cloud.cfg.d/05_logging.cfg

# Enable LVM socket daemons
for socket in lvm2-lvmetad dm-event; do
ln -s "/usr/lib64/systemd/system/${socket}.socket" \
    "chroot/etc/systemd/system/multi-user.target.wants/${socket}.socket"
done

# Uniqueness
echo > chroot/etc/machine-id

# SSH oddity
chown root chroot/var/empty
ln -s '/usr/lib64/systemd/system/sshd.service' \
    'chroot/etc/systemd/system/multi-user.target.wants/sshd.service'

# Allow NFS client mounts
ln -s '/usr/lib64/systemd/system/nfs-client.target' \
    'chroot/etc/systemd/system/multi-user.target.wants/nfs-client.target'
ln -s '/usr/lib64/systemd/system/nfs-client.target' \
    'chroot/etc/systemd/system/remote-fs.target.wants/nfs-client.target'

rm -f /root/systemd.squashfs || true
rm -f /root/stage3-systemd.tar.xz || true

mksquashfs chroot /root/systemd.squashfs &
tar cJf /root/stage3-systemd.tar.xz -C chroot . &
wait
