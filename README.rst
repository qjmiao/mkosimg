===============================
Build OS Image (CentOS, Fedora)
===============================

Overview
========
``mkosimg.{ct6,fc19}`` scripts can be used to build CentOS-6.5 or Fedora-19 OS
image which can be used as QEMU/KVM disk image or directly written to USB disk
to boot a physical machine.

In addition, ``mkosimg.{ct6,fc19}`` scripts can be used to install CentOS-6.5 or
Fedora-19 directly on block device including USB disk.

Prerequisites
=============
``mkosimg.ct6`` runs under CentOS-6.5/x86_64 environment.

``mkosimg.fc19`` runs under Fedora-19/x86_64 environment.

Please make sure you have installed both ``kpartx`` and ``parted`` packages.

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

  dd if=/dev/zero of=fc19.img bs=1M count=4K

For smaller image file (2G bytes), please use *count=2K*.

Build OS image
--------------
The simplest way::

  ./mkosimg.fc19 --dev=fc19.img # using image file
  ./mkosimg.fc19 --dev=/dev/sdX # or using block device

The built OS image uses *localhost* as hostname and gets eth0 settings through
*DHCP*.

More complicated way::

  ./mkosimg.fc19 --dev=fc19.img --hostname=fc19 --ipaddr==192.168.1.100 \
      --netmask=255.255.255.0 --gateway=192.168.1.1 --dns=8.8.8.8

Using OS Image
==============
QEMU/KVM
--------
::

  qemu-system-x86_64 -drive file=os.img,if=virtio -net user -net nic,model=virtio

USB boot disk
-------------
::

  dd if=os.img of=/dev/sdX bs=1M count=4K # using dd command
  cp os.img /dev/sdX # or using cp command
