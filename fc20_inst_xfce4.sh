#!/bin/sh
#
# Copyright (C) 2014 Eric Miao <qjmiao@gmail.com>. All rights reserved.
# License: GPL
#

xfce4_pkgs="
adwaita-cursor-theme
adwaita-gtk2-theme
adwaita-gtk3-theme
dejavu-sans-fonts
dejavu-sans-mono-fonts
dejavu-serif-fonts
fedora-icon-theme
gnome-icon-theme-legacy
lightdm
network-manager-applet
xorg-x11-drv-evdev
xorg-x11-drv-vesa
xfdesktop
xfce4-appfinder
xfce4-session
xfce4-settings
xfce4-terminal
"

yum install $xfce4_pkgs
