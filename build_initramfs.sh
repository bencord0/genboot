#!/bin/bash
set -xe
KVER=$(cd /usr/src/linux; make kernelrelease)

# Dracut is needed on the host
EMERGE_FLAGS="--buildpkg --getbinpkg --update --jobs --deep --newuse"
eix -qI sys-kernel/dracut || emerge $EMERGE_FLAGS --usepkg --oneshot \
    sys-kernel/dracut

dracut --no-compress -f /root/initramfs.cpio $KVER -i /root/systemd.squashfs /root.squashfs
chmod a+r /root/initramfs.cpio

dracut --xz -f /root/initramfs.nosquash $KVER
chmod a+r /root/initramfs.nosquash
