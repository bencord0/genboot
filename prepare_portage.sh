#!/bin/bash
set -x
TOPDIR=$(dirname $0)

mkdir -p /etc/portage/
cp "$TOPDIR"/package.mask /etc/portage/package.mask

