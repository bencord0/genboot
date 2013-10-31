#!/bin/bash
cd /usr/lib/dracut/modules.d

mkdir -p 80console
cat << EOF > 80console/module-setup.sh
#!/bin/bash

check() {
    return 0
}

depends() {
    return 0
}

install() {
    inst "\$moddir/console-tty0.conf" /etc/cmdline.d/console-tty0.conf
    inst "\$moddir/console-ttyS0.conf" /etc/cmdline.d/console=ttyS0.conf
}
EOF
chmod +x 80console/module-setup.sh

echo 'console=tty0' > 80console/console-tty0.conf
echo 'console=ttyS0' > 80console/console-ttyS0.conf

mkdir -p 81squashedaufs-root
cat << EOF > 81squashedaufs-root/module-setup.sh
#!/bin/bash
check() {
    return 0
}

depends() {
    return 0
}

install() {
    inst_hook cmdline 81 "\$moddir/cmdline-squashedaufs-root.sh"
    inst_hook pre-mount 81 "\$moddir/mount-squashedaufs-root.sh"
    inst_hook pre-pivot 81 "\$moddir/pre-pivot-squashedaufs-root.sh"
    inst "\$moddir/squashedaufs-root.conf" /etc/cmdline.d/squashedaufs-root.conf
}
EOF
chmod +x 81squashedaufs-root/module-setup.sh

cat << EOF > 81squashedaufs-root/cmdline-squashedaufs-root.sh
#!/bin/sh
case "$root" in
    *.squashfs)
        wait_for_dev "$root"
        rootok = 1
        USING_SQUASHEDAUFS=1
        ;;
esac
EOF
chmod +x 81squashedaufs-root/cmdline-squashedaufs-root.sh

cat << EOF > 81squashedaufs-root/mount-squashedaufs-root.sh
#!/bin/bash
mount_squashfs_as_aufs()
{
    info "Creating a tmpfs for root"
    mkdir -p /tmproot
    mount -t tmpfs tmpfs /tmproot

    info "Mounting squashfs"
    mkdir -p /squashroot
    mount -t squashfs "$root" /squashroot

    info "Unioning rootfs"
    mount -t aufs -o br:/tmproot:/squashroot none /sysroot
}

if [ -n USING_SQUASHEDAUFS ]
then
    mount_squashfs_as_aufs
fi
EOF
chmod +x 81squashedaufs-root/mount-squashedaufs-root.sh

cat << EOF >> 81squashedaufs-root/pre-pivot-squashedaufs-root.sh
#!/bin/bash
mkdir -p /sysroot/lib/modules
cp -r /lib/modules/* /sysroot/lib/modules/
EOF
chmod +x 81squashedaufs-root/pre-pivot-squashedaufs-root.sh

echo 'root=/root.squashfs' >> 81squashedaufs-root/squashedaufs-root.conf