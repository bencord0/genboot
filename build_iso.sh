#!/bin/bash
set -x

emerge -k1ub virtual/cdrtools sys-boot/syslinux

I=/root/gentoo-systemd.iso
M=cdroot

rm -f "$I"
rm -r "$M"
mkdir -p "$M"


function clean_up () {
    set +e
    rm -r "$M"
}
trap 'clean_up' EXIT

set -e
cp -vt "$M" \
  /root/vmlinuz \
  /usr/share/syslinux/isolinux.bin \
  /usr/share/syslinux/ldlinux.c32

cat << EOF > "$M"/syslinux.cfg
PROMPT 10
TIMEOUT 20
DEFAULT gentoo-systemd
ONTIMEOUT gentoo-systemd

LABEL gentoo-systemd
KERNEL vmlinuz
EOF

mkisofs \
  -eltorito-boot isolinux.bin \
  -no-emul-boot -boot-load-size 4 \
  -boot-info-table -eltorito-catalog boot.cat \
  -full-iso9660-filenames -rock \
  -V gentoo-systemd \
  -o "$I" "$M"
