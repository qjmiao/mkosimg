=========================
Build CentOS 6.4 OS Image
=========================

Overview
========
``mkosimg_c6.sh`` can be used to build CentOS 6.4 OS image which can be used as QEMU/KVM VM image
or directly written to USB disk to boot a physical machine.

Prerequisites
=============
``mkosimg_c6.sh`` runs under CentOS 6.4 environment.

In addition, please make sure you have installed ``kpartx`` and ``parted`` packages.

::

  yum install kpartx parted

Get Scripts
===========
::

  git clone https://github.com/qjmiao/mkosimg.git

Steps to Build OS Image
=======================
Prepare image file
------------------
::

  dd if=/dev/zero of=ctos64.img bs=1M count=4K

For smaller image file (2G bytes), please use *count=2K*.

Build OS image
--------------
Simplest way::

  ./mkosimg_c6.sh --image=ctos64.img

The built OS image uses *localhost.localdomain* as hostname and gets eth0 settings through *DHCP*.

More complicated way::

  ./mkosimg_c6.sh --image=ctos64.img --hostname=ctos64.net --ipaddr==192.168.1.100 --netmask=255.255.255.0 --gateway=192.168.1.1 --dns=8.8.8.8

If you have CentOS installation media (CDROM or ISO file) mounted, you can add *--repo=c6-media* option to accelerate image building.

Using OS Image
==============
QEMU/KVM
--------
::

  qemu-system-$(arch) -drive file=ctos64.img,if=virtio -net user -net nic,model=virtio

USB boot disk
-------------
::

  dd if=ctos64.img of=/dev/sdX bs=1M count=4K conv=sync
