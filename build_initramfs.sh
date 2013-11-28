#!/bin/bash
set -x

dracut -f /root/initramfs -i /root/systemd.squashfs /root.squashfs 
chmod a+r /root/initramfs

dracut -f /root/initramfs.nosquash
chmod a+r /root/initramfs.nosquash
