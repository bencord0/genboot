#!/bin/bash
set -x

eclean-dist &
eclean-pkg &
wait

tar cJf /root/portage.tar.xz -C /usr portage
