#!/bin/sh

xfce4_pkgs="
dejavu-sans-fonts
dejavu-sans-mono-fonts
dejavu-serif-fonts
fedora-icon-theme
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
