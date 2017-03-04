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
ln -sf "/usr/lib64/systemd/system/systemd-${svc}.service" \
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

# Rewrite cloud init service files
cat << EOF > "chroot/usr/lib64/systemd/system/cloud-config.service"
[Unit]
Description=Apply the settings specified in cloud-config
After=network-online.target syslog.target cloud-config.target
Requires=cloud-config.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/bin/cloud-init modules --mode=config
RemainAfterExit=yes
TimeoutSec=0

# Output needs to appear in instance console output
StandardOutput=journal+console

[Install]
WantedBy=multi-user.target
EOF

cat << EOF > "chroot/usr/lib64/systemd/system/cloud-config.target"
[Unit]
Description=Cloud-config availability
Requires=cloud-init-local.service cloud-init.service
EOF

cat << EOF > "chroot/usr/lib64/systemd/system/cloud-final.service"
[Unit]
Description=Execute cloud user/final scripts
After=network-online.target syslog.target cloud-config.target cloud-config.service rc-local.service
Requires=cloud-config.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/bin/cloud-init modules --mode=final
RemainAfterExit=yes
TimeoutSec=0

# Output needs to appear in instance console output
StandardOutput=journal+console

[Install]
WantedBy=multi-user.target
EOF

cat << EOF > "chroot/usr/lib64/systemd/system/cloud-init-local.service"
[Unit]
Description=Initial cloud-init job (pre-networking)
Wants=local-fs.target
Before=network.target
After=local-fs.target

[Service]
Type=oneshot
ExecStart=/usr/bin/cloud-init init --local
RemainAfterExit=yes
TimeoutSec=0

# Output needs to appear in instance console output
StandardOutput=journal+console

[Install]
WantedBy=multi-user.target
EOF

cat << EOF > "chroot/usr/lib64/systemd/system/cloud-init.service"
[Unit]
Description=Initial cloud-init job (metadata service crawler)
After=local-fs.target network-online.target cloud-init-local.service
Before=sshd.service
Requires=network-online.target
Wants=local-fs.target cloud-init-local.service sshd.service

[Service]
Type=oneshot
ExecStartPre=-/usr/bin/sleep 5
ExecStart=/usr/bin/cloud-init init
RemainAfterExit=yes
TimeoutSec=0

# Output needs to appear in instance console output
StandardOutput=journal+console

[Install]
WantedBy=multi-user.target
EOF

cat << EOF > "chroot/etc/systemd/system/cloud.target"
[Unit]
Requires=default.target
After=default.target
AllowIsolate=yes
EOF

# Enable Cloud-init
for svc in cloud-config.target cloud-config.service cloud-final.service; do
ln -sf "/usr/lib64/systemd/system/${svc}" \
    "chroot/etc/systemd/system/cloud.target.wants/${svc}"
done

# Fix nfs clients
cat << EOF > "chroot/usr/lib64/systemd/system/rpcbind.target"
[Unit]
Requires=rpcbind.service
After=rpcbind.service
EOF

# Enable LVM socket daemons
for socket in lvm2-lvmetad dm-event; do
ln -sf "/usr/lib64/systemd/system/${socket}.socket" \
    "chroot/etc/systemd/system/multi-user.target.wants/${socket}.socket"
done

# Mount zfs filesystems on boot
ln -sf "/usr/lib64/systemd/system/zfs.service" \
    "chroot/etc/systemd/system/multi-user.target.wants/zfs.service"

# Uniqueness
echo > chroot/etc/machine-id

# SSH oddity
chown root chroot/var/empty
ln -sf '/usr/lib64/systemd/system/sshd.service' \
    'chroot/etc/systemd/system/multi-user.target.wants/sshd.service'

rm -f /root/systemd.squashfs || true
rm -f /root/stage3-systemd.tar.xz || true

tar cJf /root/stage3-systemd.tar.xz -C chroot . &
mksquashfs chroot /root/systemd.squashfs
