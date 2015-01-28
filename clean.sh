#!/bin/bash

mnt=/tmp/tmp.$1
dev=/dev/loop0

umount $mnt/run
umount $mnt/sys
umount $mnt/proc
umount $mnt/dev
umount $mnt
rmdir $mnt

kpartx -d $dev
losetup -d $dev
