#!/bin/bash
set -o errexit

usage() {
    cat <<EOF
Usage: mkosimg_f20 [OPTIONS]

OPTIONS:
    --help                  print this message and exit
    --dev=DEV               block device name
    --hostname=HOSTNAME     hostname (default: localhost)
    --ipaddr=IPADDR         eth0 address (default: DHCP)
    --netmask=NETMASK       eth0 netmask (default: DHCP)
    --gateway=GATEWAY       gateway address (default: DHCP)
    --dns=DNS               nameserver (default: DHCP)
    --repo=REPO             yum repo (default: fedora)
EOF

    exit 1
}

hostname=localhost
repo=fedora

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

    --repo=*)
        repo=${opt/--*=}
        ;;

    *)
        echo "Invalid option: $opt"
        usage
        ;;
    esac
done

if [ -z "$dev" ]; then
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
echo "device   : $dev"
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

echo "repo     : $repo"
echo "+++++++++++++++++++++++++++++++"
echo

if [ ! -b $dev ]; then
    echo "No such block device: $dev"
    exit 1
fi

rdev=${dev}1

parted $dev -s -- mklabel msdos
parted $dev -s -- unit s mkpart primary 2048 -1
parted $dev -s -- set 1 boot

mkfs.ext4 $rdev
uuid=$(blkid -o value -s UUID $rdev)

mnt=$(mktemp -d)
mount $rdev $mnt

rpm --root=$mnt --initdb
rpm --root=$mnt -i http://mirrors.163.com/fedora/releases/20/Fedora/x86_64/os/Packages/f/fedora-release-20-1.noarch.rpm
rpm --root=$mnt --import $mnt/etc/pki/rpm-gpg/RPM-GPG-KEY-fedora-20-x86_64

mkdir -p $mnt/{dev,proc,sys,run}
mount -t devtmpfs none $mnt/dev
mount -t proc none $mnt/proc
mount -t sysfs none $mnt/sys
mount -t tmpfs none $mnt/run
mkdir $mnt/run/lock #XXX ppp

##{{
cat > $mnt/etc/fstab <<EOF
UUID=$uuid / ext4 defaults 1 1
EOF
##}}

pkgs="
NetworkManager
dhclient
e2fsprogs
grub2
kbd
kernel
less
net-tools
openssh-server
passwd
yum
vim-minimal
"

yum --installroot=$mnt -y install $pkgs
yum --installroot=$mnt clean all

cat > $mnt/etc/selinux/config <<EOF
SELINUX=disabled
EOF

echo $hostname > $mnt/etc/hostname

if [ -n "$dns" ]; then
    echo "nameserver $dns" > $mnt/etc/resolv.conf
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
GATEWAY=$gateway
EOF
fi
##}}

echo LANG=en_US.UTF-8 > $mnt/etc/locale.conf

cat > $mnt/etc/sysconfig/kernel <<EOF
UPDATEDEFAULT=yes
DEFAULTKERNEL=kernel
EOF

cp $mnt/etc/skel/.bash* $mnt/root

chroot $mnt passwd --stdin root <<EOF
fedora
EOF

kpkg=$(rpm --root=$mnt -q kernel)
kver=${kpkg/kernel-}
chroot $mnt mkinitrd /boot/initramfs-$kver.img $kver

##{{
cat > $mnt/etc/default/grub <<EOF
GRUB_CMDLINE_LINUX="net.ifnames=0"
GRUB_DISABLE_SUBMENU=true
GRUB_DISABLE_OS_PROBER=true
GRUB_GFXPAYLOAD_LINUX=text
EOF
##}}

chroot $mnt grub2-install $dev
chroot $mnt grub2-mkconfig -o /boot/grub2/grub.cfg

cp f20_inst_xfce4.sh $mnt/root

umount $mnt/run
umount $mnt/sys
umount $mnt/proc
umount $mnt/dev
umount $mnt
rmdir $mnt
