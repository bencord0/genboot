#!/bin/bash
set -x
KVER=$(cd /usr/src/linux; make kernelrelease)

# Dracut is needed on the host
EMERGE_FLAGS="--buildpkg --getbinpkg --update --jobs --deep --newuse"
eix -qI sys-kernel/dracut || emerge $EMERGE_FLAGS --usepkg --oneshot \
    sys-kernel/dracut

dracut -f /root/initramfs $KVER -i /root/systemd.squashfs /root.squashfs 
chmod a+r /root/initramfs

dracut -f /root/initramfs.nosquash $KVER
chmod a+r /root/initramfs.nosquash
