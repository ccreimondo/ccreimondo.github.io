---
layout: post
title:  "Introduction to Linux Kernel (v2.6) Debugging"
date:   2016-3-18 00:00:00
categories: linux
---

慢慢填坑。

## 内核源码获取和编译环境
- 内核源码版本为 2.6.32.70。可在 [Linux Kernel Pub](https://www.kernel.org/pub/linux/kernel/) 获取。
- 综合考虑是否有在线软件源服务、GCC 版本、系统环境熟悉程度等因素，我们可以选择 Ubuntu 10.04 (lynx) 作为内核编译、运行环境。
[系统下载](http://old-releases.ubuntu.com/releases/10.04.3/)
  - Ubuntu 10.04 LTS includes the 2.6.32-21.32 kernel based on 2.6.32.11.
  - GCC 4.4.3

## 虚拟机配置和系统安装
虚拟机为 VirtualBox。创建虚拟机的过程中，我们可以选择最少的硬件（但需要一块网卡，可以取消 Audio 之类的硬件），同时添加一个串口设备以供 KGDB 使用。添加串口设备：
![virtualbox-serial-port-configurations]({{ site.baseurl }}/assets/images/virtualbox-serial-port-configurations.png)

图中，我选择 Port Mode 为 TCP 并自定义了一个端口 9999，这样该虚拟串口便监听在 \*:9999。在 GDB 中，我们可以通过命令 `target remote <host ip>:9999` 连上该串口并对内核进行调试。

Ubuntu Server x86 版本足够满足我们的需求。安装系统过程中，我们一律下一步下一步即可（问及是否加密 home？选否即可）。当然，我们需要留意一下时区、账户密码等信息。在 Software Selection 一页，记得勾选一个 OpenSSH Server。

## 安装一些工具
在 Ubuntu 里，我们可以通过 `apt-get install <package name>` 安装一些软件。

- 安装编译工具。`apt-get install build-essential` 即可。`apt-cache show build-essential` 了解一下这个软件包。
- 安装 libncurses-dev 以便我们可以进行 menuconfig。`apt-get install libncurses-dev`.

## 配置、编译内核
配置内核有点小挑战。这里，我推荐先 `make help`，了解一下 Makefile 给我们提供了哪些方便的命令。

- `make defconfig` 直接生成一份简单的配置文件，编译过程也很快，但编译后的内核会出现 kernel panic: unsupported feature，我猜想可能与未启用一些驱动有关。
- 我们可以在 `make defconfig` 产生的配置文件的基础上，`make menuconfig` 进行一些定制，不过这需要你能判断出必要的选项。
- 当然，我们可以直接 `make menuconfig`，它也会产生一个配置文件（如果源码根目录存在 .config，它默认打开该配置文件），但编译耗时很长。
- 最后，我们可以 `make localmodconfig` 获得一个与当前系统环境相关的简单的配置文件。期间，我们需要根据提示进行几个选择（基本上直接 No）。综上，这个方式挺友好。

`make -j [processor count] > /dev/null` 进行编译。`-j` 用于指定 GCC 衍生出的 worker 数量。这样，我们可以充分利用多核环境，进行并行编译以提高编译速度。`>/dev/null` 可以帮助我们隐去大量编译过程信息，当然，warning、error 之类的信息仍会保留。

## 安装内核和配置 GRUB
- `make install` 会将 .config、编译生成的 vmlinuz 拷贝到系统 /boot 目录下。
- `make modules_install` 将模块安装到 /lib/modules 目录下。
- 我们还需要定制一个 initramfs。`update-initramfs -c -k <kernel version>` 即会在 /boot 目录下生成一个 initramfs 。`-c` 为创建，`-k` 指定内核版本号，e.g. `update-initramfs -c -k 2.6.32.70`.
- 最后，`update-grub` 将自动为我们更新 grub.cfg。至此，系统开机会默认启动我们的内核。
- 我们可以通过配置 /etc/default/grub 改变 GRUB 的开机行为。e.g. 注释掉 /etc/default/grub 中的 GRUB_HIDDEN_TIMEOUT=0 可让 GRUB 在系统开机时出现内核选择菜单。

## 使用 printk 进行调试

## 使用 SystemTap 进行系统诊断

## 使用 KGDB 进行调试

## References:
- [Ubuntu 10.04 LTS Technical Overview](https://wiki.ubuntu.com/LucidLynx/TechnicalOverview)
- [Linux 内核编译初学者指南](http://zhoutall.com/archives/635)
- [使用 GDB 和 KVM 调试 Linux 内核与模块](http://www.ibm.com/developerworks/cn/linux/1508_zhangdw_gdb/index.html)
- [Using kgdb, kdb and the kernel debugger internals](https://www.kernel.org/doc/htmldocs/kgdb/index.html)

