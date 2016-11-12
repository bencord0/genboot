#!/bin/bash
set -x

eclean-dist &
eclean-pkg &
wait

tar cf /root/portage.tar -C /usr portage/
tar uf /root/portage.tar -C /var/lib/portage distfiles/ packages/
xz /root/portage.tar
