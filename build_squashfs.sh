#!/bin/bash
rm -f /root/systemd.squashfs||true;
mksquashfs chroot /root/systemd.squashfs
