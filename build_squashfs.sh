#!/bin/bash
set -x

rm -f /root/systemd.squashfs||true;
mksquashfs -no-progress chroot /root/systemd.squashfs
