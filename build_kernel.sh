#!/bin/bash

emerge -u sys-kernel/aufs-sources

cd /usr/src/linux

zcat /proc/config.gz > .config
make olddefconfig
make targz-pkg

cd /
tar xzvf /usr/src/linux/linux*.tar.gz

depmod
cp /boot/vmlinuz* /root/vmlinuz