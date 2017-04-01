#!/bin/bash

set -e

apt update
apt install -y git gcc make pkg-config libz-dev libssl-dev libarchive-dev
XBPS_SRC=`mktemp -d /tmp/xbps.XXX`
git clone https://github.com/voidlinux/xbps.git $XBPS_SRC
cd $XBPS_SRC
./configure --prefix=/
make
make install

VOID_IMG=`mktemp -d /tmp/void.XXX`
xbps-install -y -S -R http://repo3.voidlinux.eu/current -r $VOID_IMG base-voidstrap

