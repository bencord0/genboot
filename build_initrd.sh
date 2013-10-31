#!/bin/bash
rm -f /root/systemd.squashfs||true;
mksquashfs chroot /root/systemd.squashfs

dracut -f /root/initramfs -i /root/systemd.squashfs /root.squashfs 
chmod a+r /root/initramfs