#!/bin/bash
set -o errexit

apt-get install -y debootstrap qemu-utils zerofree

DEB_SRC=http://cn.archive.ubuntu.com
MNT=$PWD/mnt

qemu-img create ubuntu1204.img 1G

modprobe nbd nbds_max=2 max_part=4
qemu-nbd -d /dev/nbd0
qemu-nbd -c /dev/nbd0 ubuntu1204.img

##{{
fdisk /dev/nbd0 <<EOF
n




w
EOF
##}}

mkfs.ext4 /dev/nbd0p1
UUID=$(blkid -o value -s UUID /dev/nbd0p1)

mkdir -p $MNT
mount /dev/nbd0p1 $MNT

debootstrap --include=grub-pc,linux-virtual,openssh-server precise $MNT $DEB_SRC
chroot $MNT apt-get clean

cat > $MNT/etc/fstab <<EOF
UUID=$UUID / ext4 defaults 0 1
EOF

cat > $MNT/etc/hostname <<EOF
ubuntu.net
EOF

##{{
cat > $MNT/etc/network/interfaces <<EOF
auto lo
iface lo inet loopback

auto eth0
iface eth0 inet dhcp
EOF
##}}

passwd -R $MNT <<EOF
root
root
EOF

chroot $MNT locale-gen en_US.UTF-8
chroot $MNT update-locale LANG=en_US.UTF-8

cat > $MNT/etc/apt/sources.list <<EOF
deb $DEB_SRC precise main
deb $DEB_SRC precise-updates main
deb $DEB_SRC precise-security main
EOF

mount --bind /dev $MNT/dev
chroot $MNT grub-install /dev/nbd0 --modules="part_msdos"

while fuser $MNT/dev; do
    sleep 1
done
umount $MNT/dev

##{{
cat > $MNT/boot/grub/grub.cfg <<EOF
set default=0
set timeout=3
set root=(hd0,1)

menuentry "Ubuntu, with Linux 3.2.0-23-virtual" {
    linux /boot/vmlinuz-3.2.0-23-virtual root=UUID=$UUID ro
    initrd /boot/initrd.img-3.2.0-23-virtual
}
EOF
##}}

umount $MNT
zerofree /dev/nbd0p1
qemu-nbd -d /dev/nbd0
qemu-img convert -c -O qcow2 ubuntu1204.img ubuntu1204.qcow2.img

## qemu-system-$(arch) -drive file=ubuntu1204.img,if=virtio -net user -net nic,model=virtio
##
## </etc/default/grub> {{
## #GRUB_HIDDEN_TIMEOUT=0
## #GRUB_HIDDEN_TIMEOUT_QUIET=true
## GRUB_CMDLINE_LINUX_DEFAULT=""
## GRUB_TERMINAL=console
## }}
##
## </etc/localtime>
##
## apt-get update
## apt-get dist-upgrade
