#!/bin/bash
set -x

rm -f /root/systemd.squashfs||true;
mksquashfs chroot /root/systemd.squashfs
