---
layout: post
title:  "Settings Up Dual Monitors with Xrandr on Debian HOWTO"
date:   2014-12-11 13:33:11
categories: howto linux
---
- VGA1: external monitor
- LVDS1: internal monitor

`xrandr --output VGA1 --mode 1920x1080 --pos 1366x0 --output LVDS1 --mode 1366x768 --pos 0x312`

http://www.jejik.com/articles/2008/10/setting_up_dual_monitors_system-wide_with_xrandr_on_debian_lenny
