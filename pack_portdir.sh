#!/bin/bash
set -x

eclean-dist
eclean-pkg

tar cJf /root/portage.tar.xz -C /usr portage
