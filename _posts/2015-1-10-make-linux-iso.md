---
layout: post
title:  "Try to Create a Linux ISO"
date:   2015-1-10 13:33:11
categories: howto linux
---
This is just a scratch and I tried with Kubuntu...

## Prepare

~~~bash
# su root
$su root
# make a workspace
mkdir os
# copy one src-linux.iso into os
cp linux.iso os
# make a folder to mount the linux.iso and mount
mkdir media && mount -o loop linux.iso media
# file mounted in the media is read-only, cp to another folder
mkdir iso.linux && cp -af media iso.linux
~~~

## Related Directories or Files in iso.linux

~~~bash
iso.linux
|
+---casper
|   |
|   +---filesystem.squashfs    # main system
|   |
|   +---initrd.lz    # a tiny temp file system to boot kernel
|
|
+---isolinux    # some configure files for linux installing?
|   +
|   |
|   \---lang
...
~~~

## Extract Core System

~~~bash
# move filesystem.squashfs into os
mv iso.linux/casper/filesystem.squashfs .
# bring system from filesyste.squashfs into os.linux
unsquashfs -d os.linux filesystem.squashfs
~~~

![os linux files](http://blog.reimondo.org/images/blog/linux-mkiso-about-os-linux.png)

## Custom sth.

~~~bash
# you can chroot os.linux
chroot os.linux
# We can mount some directories and don't forget
# to unmount after finish the work.
mount -t proc none /proc
mount --bind sys /sys
mount --bind etc /etc
... # missing...
# add DNS if using apt-get
echo "202.5.5.5" > etc/hostname  # Ali public DNS
# Modify themes of bootstrap?
cd os.linux/lib/plymouth/themes/
# when finish, save it into iso.linux/casper
# only one filesystem.squashfs in casper/
cd os && mksquashfs os.linux iso.linux/casper/filesystem.squashfs

# modify initrd.lz
# We cae use 7z to extract it.
apt-get install p7zip-full
# cd into casper
cd os/iso.linux/casper
7z x initrd.lz
# create a tmp file to save initrd file
mkdir TMP && cd TMP && cpio -i < ../initrd
# U can try modify themes?
cd lib/plymouth/themes
# when finish, save to initrd.lz
find . | cpio -o -H newc | lzma -7 > ../initrd.lz
# delete tmp files
cd .. && rm -rf TMP initrd
~~~

## Repackage into iso

~~~bash
# In iso.linux, execute the following shell script.
# I use #genisoimage in my debian-xfce or it should be #mkisofs.
# $start shell script
#!/bin/sh
NAME=$1

rm -f ../$NAME.iso

echo Generating iso files $NAME...

genisoimage -r -V "$NAME" --cache-inodes -J -l -b \
isolinux/isolinux.bin -c isolinux/boot.cat -no-emul-boot \
-boot-load-size 4 -boot-info-table -o ../$NAME.iso .
# $end shell script
cd iso.linux && sh genisoimage.sh my_linux.iso
# DOWN! You can see a new my_linux.iso in os.
~~~

## Tasks

- Try docker
- Explore chroot
- Try `mksquashfs os.my_debian iso.debian/casper/filesystem.squashfs`

