#!/bin/bash
set -x

dracut -f /root/initramfs -i /root/systemd.squashfs /root.squashfs 
chmod a+r /root/initramfs
