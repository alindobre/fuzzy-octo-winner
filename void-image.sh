#!/bin/bash

set -e

sys:deps:install() {
  case `lsb_release -i -s` in
    Ubuntu)
      apt update
      apt install -y git gcc make pkg-config zlib1g-dev libssl-dev libarchive-dev
      ;;
  esac
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

void:container() {
  local SERVICE
  echo VIRTUALIZATION=contain >>$VOID_IMG/etc/rc.conf
  rm -fv $VOID_IMG//etc/runit/runsvdir/default/*
  for SERVICE in agetty-console dhcpcd-eth0 sshd; do
    ln -svfn /etc/sv/$SERVICE $VOID_IMG/etc/runit/runsvdir/default/$SERVICE
  done
  mkdir $VOID_IMG/root/.ssh
  ssh-add -L >> $VOID_IMG/root/.ssh/authorized_keys
  chmod 700 $VOID_IMG/root/.ssh
  chmod 600 $VOID_IMG/root/.ssh/authorized_keys
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
void:container
void:wordpress

echo Image is available at $VOID_IMG
