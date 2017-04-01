#!/bin/bash

set -e

sys:deps:install() {
  apt update
  apt install -y git gcc make pkg-config zlib1g-dev libssl-dev libarchive-dev
}

xbps:src:pull() {
  XBPS_SRC=`mktemp -d /tmp/xbps.XXX`
  git clone https://github.com/voidlinux/xbps.git $XBPS_SRC
}

xbps:src:install() {
  if ! type xbps-install 2>/dev/null; then
    pushd $XBPS_SRC
    ./configure --prefix=/
    make
    make install
    popd
    rm -rf $XBPS_SRC
  fi
}

void:bootstrap() {
  xbps-install -y -S -R http://repo3.voidlinux.eu/current -r $VOID_IMG base-voidstrap
}

void:wordpress() {
  xbps-install -y -S -R http://repo3.voidlinux.eu/current -r $VOID_IMG \
    nginx mariadb mariadb-client php-fpm php-mysql libmagick-devel
}

sys:deps:install
xbps:src:pull
xbps:src:install

VOID_IMG=`mktemp -d /tmp/void.XXX`
mkdir -p $VOID_IMG/var/db/xbps/keys
cp -v $XBPS_SRC/data/*.plist $VOID_IMG/var/db/xbps/keys

void:bootstrap
void:wordpress

echo Image is available at $VOID_IMG
