#!/bin/bash
set -o errexit

##
## http://intgat.tigress.co.uk/rmy/uml/zerofree-1.0.3.tgz
## yum install e2fsprogs-devel qemu-img
##
## mount /dev/sr0 /media/CentOS
##

usage() {
    echo "\
Usage: mkosimg_c6 [OPTIONS]

Options:
    --help                  print this message and exit
    --dev=DEV               block device name
    --hostname=HOSTNAME     hostname (default: centos)
    --ipaddr=IPADDR         eth0 address (DHCP if not specified)
    --netmask=NETMASK       eth0 netmask
    --gateway=GATEWAY       gateway address
    --dns=DNS               nameserver
"

    exit 1
}

for opt in "$@"; do
    case $opt in
    --help)
        usage
        ;;

    --dev=*)
        dev=${opt/--*=}
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

if [ -z "$dev" ]; then
    usage
fi

if [ -z "$hostname" ]; then
    hostname=centos
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
echo "dev      : $dev"
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

parted $dev -s -- mklabel msdos
parted $dev -s -- unit s mkpart primary 2048 -1
parted $dev -s -- set 1 boot

mkfs.ext4 -q ${dev}1
uuid=$(blkid -o value -s UUID ${dev}1)

mnt=$(mktemp -d)
mount ${dev}1 $mnt

rpm --root=$mnt --initdb
rpm --root=$mnt -i /media/CentOS/Packages/centos-release-6-4.el6.centos.10.x86_64.rpm
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

pkgs="yum openssh-server passwd e2fsprogs rsyslog kernel acpid man vim-enhanced"

if [ -z "$ipaddr" ]; then
    pkgs+=" dhclient"
fi

yum --installroot=$mnt --disablerepo=* --enablerepo=c6-media -y install $pkgs
yum --installroot=$mnt clean all

umount $mnt/dev

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

##{{
cat > $mnt/boot/grub/grub.conf <<EOF
default=0
timeout=3

title CentOS (2.6.32-358.el6.x86_64)
    kernel /boot/vmlinuz-2.6.32-358.el6.x86_64 root=UUID=$uuid ro nomodeset
    initrd /boot/initramfs-2.6.32-358.el6.x86_64.img
EOF
##}}

ln -s ../boot/grub/grub.conf $mnt/etc

grub-install --root-directory=$mnt --no-floppy $dev

umount $mnt

##
## zerofree ${dev}1
## qemu-img convert -c -O qcow2 $dev ctos6.img
##
