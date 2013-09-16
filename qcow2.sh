#!/bin/bash
set -o errexit

raw_img=$1
qcow2_img=$2

if [ -z "$raw_img" -o -z "$qcow2_img" ]; then
    echo "Usage: qcow2.sh <raw_image> <qcow2_image>"
    exit 1
fi

if ! which zerofree 2>&1 > /dev/null; then
    echo "No zerofree found"
    exit 1
fi

if ! which qemu-img 2>&1 > /dev/null; then
    echo "No qemu-img found"
    exit 1
fi

if [ ! -f $raw_img ]; then
    echo "No such file: $raw_img"
    exit 1
fi

if [ -n "$(losetup -j $raw_img)" ]; then
    echo "$raw_img has associated loop device"
    exit 1
fi

dev=$(losetup -f)
rdev=/dev/mapper/$(basename $dev)p1

losetup $dev $raw_img
kpartx -a -s $dev
zerofree $rdev
kpartx -d $dev
losetup -d $dev

qemu-img convert -c -O qcow2 $raw_img $qcow2_img
