#!/bin/bash
set -xe

I=/root/gentoo-systemd.img
M=mountpath
Q="/root/$(basename "$I" .img).qcow2"
rm -f "$I"
rm -f "$Q"

truncate -s2G "$I"
echo -e 'o\nn\np\n1\n\n\nw\n' | fdisk "$I"


# In some container environments, a loop device might not be available.
ls /dev/loop0 || mknod /dev/loop0 b 7 0 || {
    echo "Unable to use loop devices."
    echo "Skipping image creation."
    exit 0
}

L="$(losetup -Pf --show "$I")"
mkfs.ext4 "$L"p1
mkdir -p "$M"

mount "$L"p1 "$M" || exit 1
function clean_up_loop () {
    set +e
    umount -l "$M"
    losetup -d "$L"
    rm -d "$M"
}
trap 'clean_up_loop' EXIT

unsquashfs -d "$M" -f /root/systemd.squashfs

mount --bind {,"$M"}/dev
mount --bind {,"$M"}/dev/pts
mount --bind {,"$M"}/proc
mount --bind {,"$M"}/sys

function clean_up_all () {
    set +e
    umount "$M"/{sys,proc,dev/pts,dev,}
    clean_up_loop
}
trap 'clean_up_all' EXIT

mkdir "$M"/boot
cp /root/vmlinuz.nosquash "$M/boot/vmlinuz"
cp /root/initramfs.nosquash "$M/boot/initramfs"
chroot "$M" grub2-install "$L"

cat << EOF > "$M/boot/grub/grub.cfg"
serial --speed=115200 --unit=0 --word=8 --parity=no --stop=1
terminal_input serial
terminal_output serial
set default=0
set timeout=1

menuentry 'Gentoo GNU/Linux' --class gentoo --class gnu-linux --class gnu --class os {
  insmod gzio
  insmod part_msdos
  insmod ext2
  echo    'Loading Gentoo GNU/Linux ...'
  linux   /boot/vmlinuz root=/dev/vda1 ro init=/usr/lib/systemd/systemd console=ttyS0 
  initrd  /boot/initramfs
}
EOF

# Enable cloud-init
for svc in config final init init-local; do
    ln -sf "/usr/lib64/systemd/system/cloud-${svc}.service" \
        "$M/etc/systemd/system/multi-user.target.wants/cloud-${svc}.service"
done

clean_up_all
trap - EXIT

EMERGE_FLAGS="--buildpkg --getbinpkg --update --jobs --deep --newuse"
eix -qI app-emulation/qemu || emerge $EMERGE_FLAGS --usepkg --oneshot \
    app-emulation/qemu

# Delete the raw image, only if conversion was successful.
qemu-img convert -c -f raw -O qcow2 "$I" "$Q" && rm "$I"
