#!/bin/bash

set -e
shopt -s extglob
CONTAINER=
[[ $1 == -c ]] && CONTAINER=1
[[ $1 == @(-h|--help) ]] && echo usage: $0 [ -c ] && exit

sys:deps:install() {
  case `lsb_release -i -s` in
    Ubuntu)
      apt update
      apt install -y git gcc make pkg-config zlib1g-dev libssl-dev libarchive-dev pwgen
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
    ./configure
    make
    make install
    popd
    rm -rf $XBPS_SRC
  fi
}

void:bootstrap() {
  xbps-install -y -S -R http://repo.voidlinux.eu/current -r $VOID_IMG base-voidstrap grub linux python
}

void:initial:config() {
  local SERVICE
  [[ $CONTAINER ]] && echo VIRTUALIZATION=contain >>$VOID_IMG/etc/rc.conf
  rm -fv $VOID_IMG/etc/runit/runsvdir/default/*
  for SERVICE in agetty-console dhcpcd-eth0 sshd; do
    ln -svfn /etc/sv/$SERVICE $VOID_IMG/etc/runit/runsvdir/default/$SERVICE
  done
  echo GETTY_ARGS=--noclear >> $VOID_IMG/etc/sv/agetty-console/conf
  mkdir $VOID_IMG/root/.ssh
  ssh-add -L >> $VOID_IMG/root/.ssh/authorized_keys
  chmod 700 $VOID_IMG/root/.ssh
  chmod 600 $VOID_IMG/root/.ssh/authorized_keys
  ROOTPW=`pwgen -n 40 1`
  chpasswd -R $VOID_IMG <<<"root:$ROOTPW"
}

image:cleanup() {
  umount -R $MOUNT
  losetup -d $LOOP
}

guest:image() {
  local SIZE IMAGE LOOP MOUNT BIND UUID
  trap image:cleanup ERR
  read SIZE _ <<< `du -xbs $VOID_IMG`
  SIZE=$(( (SIZE/512) * 3 / 2 + 4 + 256 ))
  IMAGE=$VOID_IMG-loop
  MOUNT=$VOID_IMG-mount
  dd if=/dev/zero count=$SIZE of=$IMAGE
  sfdisk -f $IMAGE <<EOF
label: gpt
unit: sectors
type=4, size=2048, attrs="LegacyBIOSBootable"
type=24
EOF
  losetup -P -f $IMAGE
  LOOP=`losetup -l -n -O NAME -j $IMAGE`
  UUID=`uuidgen`
  [[ $UUID ]]
  mkfs.xfs -L voidroot -m uuid=$UUID ${LOOP}p2
  mkdir $MOUNT
  mount ${LOOP}p2 $MOUNT
  rsync -aHXx $VOID_IMG/ $MOUNT/
  for BIND in /{sys,proc,dev}; do
    mount --rbind --make-rprivate $BIND $MOUNT$BIND
  done
  echo "UUID=$UUID / xfs defaults 0 1" >>$MOUNT/etc/fstab
  echo GRUB_TERMINAL_INPUT=console >> $MOUNT/etc/default/grub
  echo GRUB_TERMINAL_OUTPUT=console >> $MOUNT/etc/default/grub
  echo 'GRUB_CMDLINE_LINUX="net.ifnames=0 biosdevname=0"' \
    >>$MOUNT/etc/default/grub
  cp -a $MOUNT/etc/default/grub{,.final}
  echo GRUB_DISABLE_OS_PROBER=true >>$MOUNT/etc/default/grub
  echo GRUB_CMDLINE_LINUX="\"root=UUID=$UUID net.ifnames=0 biosdevname=0\"" \
    >>$MOUNT/etc/default/grub
  mkdir $MOUNT/boot/grub
  chroot $MOUNT grub-mkconfig -o /boot/grub/grub.cfg
  chroot $MOUNT grub-install --modules=part_gpt $LOOP
  mv -f $MOUNT/etc/default/grub{.final,}

  echo '[ -x /etc/rc.firstboot ] &&' \
       '/etc/rc.firstboot && chmod -x /etc/rc.firstboot' \
    >> $MOUNT/etc/rc.local
  MARKER=`awk '/^# MARKER-START-rc.firstboot-SCRIPT$/ {print NR+1; exit 0;}' $0`
  tail -n +$MARKER $0 > $MOUNT/etc/rc.firstboot
  chmod +x $MOUNT/etc/rc.firstboot
  trap "" ERR
  umount -R $MOUNT
  losetup -d $LOOP
}

sys:deps:install
xbps:src:pull

VOID_IMG=${VOID_IMG:-`mktemp -d /tmp/void.XXX`}
mkdir -p $VOID_IMG/var/db/xbps/keys
cp -v $XBPS_SRC/data/*.plist $VOID_IMG/var/db/xbps/keys
xbps:src:install
echo /usr/local/lib >/etc/ld.so.conf.d/usrlocal.conf
ldconfig

void:bootstrap
void:initial:config
guest:image

echo root password is: $ROOTPW
echo Image is available at $VOID_IMG

exit 0
# end of the main script, the rc.firstboot content follows
# MARKER-START-rc.firstboot-SCRIPT
#!/bin/bash

set -e
shopt -s nullglob

DISKS=(/dev/[hsv]da)
(( ${#DISKS[*]} > 0 ))
read SIZE </sys/block/${DISKS[0]##*/}/size

(( SIZE > 0 ))

SIZEGB=$(( SIZE / (1024*1024*2) ))
(( SIZEGB >=2 && SIZEGB <= 10 )) && SWAPGB=1
(( SIZEGB > 10 && SIZEGB <= 20 )) && SWAPGB=2
(( SIZEGB > 20 )) && SWAPGB=10
SWAPSTART=$(( SIZE - (SWAPGB * (1024*1024*2)) ))

sfdisk -d ${DISKS[0]} | grep -v -e ^first-lba: -e ^last-lba: \
  | sfdisk -f ${DISKS[0]} || :
partx -u ${DISKS[0]}
sfdisk -f -a ${DISKS[0]} <<<"start=$SWAPSTART"
sfdisk -f -N 2 ${DISKS[0]} <<<", +"
partx -u ${DISKS[0]}
xfs_growfs /
UUID=`uuidgen`
[[ $UUID ]]
mkswap -U $UUID ${DISKS[0]}3
echo "UUID=$UUID none swap sw 0 0" >> /etc/fstab
swapon ${DISKS[0]}3
df -h /
free
grub-mkconfig -o /boot/grub/grub.cfg
grub-install ${DISKS[0]}
