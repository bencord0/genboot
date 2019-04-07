#!/bin/bash
set -e

## Step 3: Configure the system
# Blank out the default root password
sed -i -e '/root/ s/*//' chroot/etc/shadow

# Write a portable fstab
cat << EOF > "chroot/etc/fstab"
/dev/vda / auto defaults 0 0
/dev/xvda / auto defaults 0 0
/dev/sda1 / auto defaults 0 0
EOF

# List mounts correctly
ln -sf /proc/mounts chroot/etc/mtab

# Create systemd admin directories
mkdir -p \
    "chroot/etc/systemd/system/multi-user.target.wants" \
    "chroot/etc/systemd/system/remote-fs.target.wants" \
    "chroot/etc/systemd/system/cloud.target.wants"


# Start systemd services
for svc in networkd resolved timesyncd; do
ln -sf "/lib/systemd/system/systemd-${svc}.service" \
    "chroot/etc/systemd/system/multi-user.target.wants/systemd-${svc}.service"
done
cat << EOF > chroot/etc/systemd/network/dhcp.network
[Match]
Name=*

[Network]
DHCP=both

[DHCP]
UseDomains=yes
EOF
ln -sf /run/systemd/resolve/resolv.conf chroot/etc/resolv.conf

cat << EOF > "chroot/etc/systemd/system/cloud.target"
[Unit]
Requires=default.target
After=default.target
AllowIsolate=yes
EOF

# Enable Cloud-init
for svc in cloud-config.target cloud-config.service cloud-final.service; do
ln -sf "/lib/systemd/system/${svc}" \
    "chroot/etc/systemd/system/cloud.target.wants/${svc}"
done

# Fix nfs clients
cat << EOF > "chroot/lib/systemd/system/rpcbind.target"
[Unit]
Requires=rpcbind.service
After=rpcbind.service
EOF

# Enable LVM socket daemons
for socket in lvm2-lvmetad dm-event; do
ln -sf "/lib/systemd/system/${socket}.socket" \
    "chroot/etc/systemd/system/multi-user.target.wants/${socket}.socket"
done

# Mount zfs filesystems on boot
ln -sf "/lib/systemd/system/zfs.service" \
    "chroot/etc/systemd/system/multi-user.target.wants/zfs.service"

# Uniqueness
echo > chroot/etc/machine-id

# SSH oddity
chown root chroot/var/empty
ln -sf '/lib/systemd/system/sshd.service' \
    'chroot/etc/systemd/system/multi-user.target.wants/sshd.service'

rm -f /root/systemd.squashfs || true
rm -f /root/stage3-systemd.tar.xz || true

tar cJf /root/stage3-systemd.tar.xz -C chroot . &
mksquashfs chroot /root/systemd.squashfs -comp xz
