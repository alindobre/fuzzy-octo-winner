#!/bin/bash

set -e

apt update
apt install -y git gcc make pkg-config zlib1g-dev libssl-dev libarchive-dev
if ! type xbps-install 2>/dev/null; then
  XBPS_SRC=`mktemp -d /tmp/xbps.XXX`
  git clone https://github.com/voidlinux/xbps.git $XBPS_SRC
  pushd $XBPS_SRC
  ./configure --prefix=/
  make
  make install
  popd
  rm -rf $XBPS_SRC
fi

VOID_IMG=`mktemp -d /tmp/void.XXX`
xbps-install -y -S -R http://repo3.voidlinux.eu/current -r $VOID_IMG base-voidstrap

echo Image is available at $VOID_IMG
