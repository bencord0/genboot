#!/bin/bash

## Step 3: Configure the system
# Blank out the default root password
sed -i -e '/root/ s/*//' chroot/etc/shadow

# Write a portable fstab
cat << EOF > "chroot/etc/fstab"
/dev/vda / auto defaults 0 0
/dev/xvda / auto defaults 0 0
EOF

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
After=network-online.target syslog.target cloud-config.service rc-local.service
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
ExecStart=/usr/bin/cloud-init init
RemainAfterExit=yes
TimeoutSec=0

# Output needs to appear in instance console output
StandardOutput=journal+console

[Install]
WantedBy=multi-user.target
EOF

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
