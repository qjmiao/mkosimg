#!/bin/bash
set -o errexit

usage() {
    echo "\
Usage: mkosimg_c6 [OPTIONS]

OPTIONS:
    --help                  print this message and exit
    --image=FILE            image file name
    --hostname=HOSTNAME     hostname (default: localhost.localdomain)
    --ipaddr=IPADDR         eth0 address (default: DHCP)
    --netmask=NETMASK       eth0 netmask
    --gateway=GATEWAY       gateway address
    --dns=DNS               nameserver
"

    exit 1
}

hostname=localhost

for opt in "$@"; do
    case $opt in
    --help)
        usage
        ;;

    --image=*)
        image=${opt/--*=}
        ;;

    --hostname=*)
        hostname=${opt/--*=}
        ;;

    --ipaddr=*)
        ipaddr=${opt/--*=}
        ;;

    --netmask=*)
        netmask=${opt/--*=}
        ;;

    --gateway=*)
        gateway=${opt/--*=}
        ;;

    --dns=*)
        dns=${opt/--*=}
        ;;

    *)
        echo "Invalid option: $opt"
        echo
        usage
        ;;
    esac
done

if [ -z "$image" ]; then
    usage
fi

if [ -z "$ipaddr" ]; then
    if [ -n "$netmask" -o -n "$gateway" -o -n "$dns" ]; then
        usage
    fi
else
    if [ -z "$netmask" -o -z "$gateway" -o -z "$dns" ]; then
        usage
    fi
fi

echo "+++++++++++++++++++++++++++++++"
echo "image    : $image"
echo "hostname : $hostname"

if [ -z "$ipaddr" ]; then
echo "ipaddr   : DHCP"
echo "netmask  : DHCP"
echo "gateway  : DHCP"
echo "dns      : DHCP"
else
echo "ipaddr   : $ipaddr"
echo "netmask  : $netmask"
echo "gateway  : $gateway"
echo "dns      : $dns"
fi
echo "+++++++++++++++++++++++++++++++"
echo

if [ ! -f $image ]; then
    echo "No such file: $image"
    exit 1
fi

if [ -n "$(losetup -j $image)" ]; then
    echo "$image has associated loop device"
    exit 1
fi

dev=$(losetup -f)
losetup $dev $image

parted $dev -s -- mklabel msdos
parted $dev -s -- unit s mkpart primary 2048 -1
parted $dev -s -- set 1 boot

kpartx -a -s $dev
rdev=/dev/mapper/$(basename $dev)p1

mkfs.ext4 $rdev
uuid=$(blkid -o value -s UUID $rdev)

mnt=$(mktemp -d)
mount $rdev $mnt

rpm --root=$mnt --initdb
release_rpm=centos-release-6-5.el6.centos.11.1.x86_64.rpm
rpm --root=$mnt -i http://mirror.centos.org/centos/6.5/os/x86_64/Packages/$release_rpm
rpm --root=$mnt --import $mnt/etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-6

mkdir -p $mnt/dev
mount --bind /dev $mnt/dev

##{{
cat > $mnt/etc/fstab <<EOF
UUID=$uuid / ext4 defaults 1 1
tmpfs /dev/shm tmpfs defaults 0 0
devpts /dev/pts devpts gid=5,mode=620 0 0
sysfs /sys sysfs defaults 0 0
proc /proc proc defaults 0 0
EOF
##}}

pkgs="yum openssh-server openssh-clients passwd e2fsprogs rsyslog kernel acpid grub vim-minimal"

if [ -z "$ipaddr" ]; then
    pkgs+=" dhclient"
fi

yum --installroot=$mnt -y install shared-mime-info
yum --installroot=$mnt -y install $pkgs
yum --installroot=$mnt clean all

cat > $mnt/etc/selinux/config <<EOF
SELINUX=disabled
EOF

sed -i -e "s/tty\[1-6\]/tty1/" $mnt/etc/sysconfig/init

if [ -n "$dns" ]; then
    echo "nameserver $dns" > $mnt/etc/resolv.conf
fi

cat > $mnt/etc/sysconfig/network <<EOF
NETWORKING=yes
HOSTNAME=$hostname
EOF

if [ -n "$gateway" ]; then
    echo "GATEWAY=$gateway" >> $mnt/etc/sysconfig/network
fi

if [ -z "$ipaddr" ]; then
    bootproto=dhcp
else
    bootproto=none
fi

##{{
cat > $mnt/etc/sysconfig/network-scripts/ifcfg-eth0 <<EOF
DEVICE=eth0
TYPE=Ethernet
ONBOOT=yes
BOOTPROTO=$bootproto
EOF

if [ -n "$ipaddr" ]; then
cat >> $mnt/etc/sysconfig/network-scripts/ifcfg-eth0 <<EOF
IPADDR=$ipaddr
NETMASK=$netmask
EOF
fi
##}}

cat > $mnt/etc/sysconfig/i18n <<EOF
LANG="en_US.UTF-8"
EOF

cat > $mnt/etc/sysconfig/kernel <<EOF
UPDATEDEFAULT=yes
DEFAULTKERNEL=kernel
EOF

cp $mnt/etc/skel/.bash* $mnt/root

chroot $mnt passwd --stdin root <<EOF
centos
EOF

kpkg=$(rpm --root=$mnt -q kernel)
kver=${kpkg/kernel-}

##{{
cat > $mnt/boot/grub/grub.conf <<EOF
default=0
timeout=3

title CentOS ($kver)
    kernel /boot/vmlinuz-$kver root=UUID=$uuid ro nomodeset
    initrd /boot/initramfs-$kver.img
EOF
##}}

ln -s ../boot/grub/grub.conf $mnt/etc

mkdir -p $mnt/boot/grub
cp $mnt/usr/share/grub/x86_64-redhat/{stage1,stage2,e2fs_stage1_5} $mnt/boot/grub

echo "(hd0) $dev" > $mnt/tmp/device.map

chroot $mnt grub --device-map=/tmp/device.map --no-floppy --batch <<EOF
root (hd0,0)
setup --stage2=/boot/grub/stage2 (hd0)
quit
EOF

rm $mnt/tmp/device.map
umount $mnt/dev
umount $mnt
rmdir $mnt
kpartx -d $dev
losetup -d $dev
