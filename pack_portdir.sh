#!/bin/bash
set -x

eclean-dist &
eclean-pkg &
wait

tar chJf /root/portage.tar.xz -C /usr portage/
