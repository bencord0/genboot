#!/bin/bash
rm -f systemd.squashfs||true;
mksquashfs chroot systemd.squashfs

dracut -f initramfs -i /root/systemd.squashfs /root.squashfs 
chmod a+r initramfs