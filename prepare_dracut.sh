#!/bin/bash
set -x
cd /usr/lib/dracut/modules.d


###########
# Console #
###########
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
    inst "\$moddir/console-ttyS0.conf" /etc/cmdline.d/console-ttyS0.conf
}
EOF
chmod +x 80console/module-setup.sh

echo 'console=tty0' > 80console/console-tty0.conf
echo 'console=ttyS0,115200' > 80console/console-ttyS0.conf

#######################################
# Rootfs = overlayfs(squashfs, tmpfs) #
#######################################
mkdir -p 81squashedoverlay-root
cat << EOF > 81squashedoverlay-root/module-setup.sh
#!/bin/bash
check() {
    return 0
}

depends() {
    return 0
}

install() {
    inst_hook cmdline 81 "\$moddir/cmdline-squashedoverlay-root.sh"
    inst_hook mount 81 "\$moddir/mount-squashedoverlay-root.sh"
    inst_hook pre-pivot 81 "\$moddir/pre-pivot-squashedoverlay-root.sh"
    inst "\$moddir/squashedoverlay-root.conf" /etc/cmdline.d/squashedoverlay-root.conf
}
EOF
chmod +x 81squashedoverlay-root/module-setup.sh

cat << EOF > 81squashedoverlay-root/cmdline-squashedoverlay-root.sh
#!/bin/sh
case "\$root" in
    *.squashfs)
        wait_for_dev "\$root"
        rootok=1
        USING_SQUASHEDOVERLAY=1
        ;;
esac
EOF
chmod +x 81squashedoverlay-root/cmdline-squashedoverlay-root.sh

cat << EOF > 81squashedoverlay-root/mount-squashedoverlay-root.sh
#!/bin/bash
mount_squashfs_as_overlay()
{
    info "Creating a tmpfs for root"
    mkdir -p /tmproot
    mount -t tmpfs tmpfs /tmproot -o size=90%
    mkdir -p /tmproot/root /tmproot/work

    info "Mounting squashfs"
    mkdir -p /squashroot
    mount -t squashfs "\$root" /squashroot

    info "Unioning rootfs"
    mount -t overlay overlay /sysroot \
	-olowerdir=/squashroot,upperdir=/tmproot/root,workdir=/tmproot/work

    info "Exposing read-only squashroot image as /mnt/squashroot"
    mkdir -p /sysroot/mnt
    : > /sysroot/mnt/squashroot
    mount --bind "\$root" /sysroot/mnt/squashroot
}

if [ -n "\$USING_SQUASHEDOVERLAY" ]
then
    mount_squashfs_as_overlay
fi
EOF
chmod +x 81squashedoverlay-root/mount-squashedoverlay-root.sh

cat << EOF > 81squashedoverlay-root/pre-pivot-squashedoverlay-root.sh
#!/bin/bash
mkdir -p /sysroot/lib/modules
cp -r /lib/modules/* /sysroot/lib/modules/
EOF
chmod +x 81squashedoverlay-root/pre-pivot-squashedoverlay-root.sh

echo 'root=/root.squashfs' > 81squashedoverlay-root/squashedoverlay-root.conf

################
# Init systemd #
################
mkdir -p 82initsystemd
cat << EOF > 82initsystemd/module-setup.sh
#!/bin/bash

check() {
    return 0
}

depends() {
    return 0
}

install() {
    inst "\$moddir/console-initsystemd.conf" /etc/cmdline.d/console-initsystemd.conf
}
EOF
chmod +x 82initsystemd/module-setup.sh

echo 'init=/usr/lib/systemd/systemd' > 82initsystemd/console-initsystemd.conf

