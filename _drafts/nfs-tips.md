# Tips on NFS Usage

## Setup nfs-server

```
# Install nfs-server
$ apt install nfs-kernel-server

# Append new entry to /etc/exports in format:
# 	dir_to_export users(attrs)
# e.g.
# 	- *, means all users can access this entry
#	- no_subtree_check, 
#	- all_squash, map all uids to the anonuid
#	- no_root_squash, wont map root uid to the anonuid
/home/rh/workspace *(rw,sync,no_subtree_check,no_root_squash,all_squash,anonuid=1000,anongid=1000)

# Start nfsd first and then exportfs
$ sudo service nfs-kernel-server start
$ sudo exportfs -rv
```

## Mount a nfs  in Linux and macOS

```
# Install nfs-client
$ apt install nfs-common

# Show the NFS server's export list
$ showmount -e 192.168.1.140

# Add new entry to /etc/fstab in format:
#	dir_to_export dir_to_mount fs_type options dump pass
192.168.1.140:/home/rh/workspace /home/rh/workspace/ser140/workspace nfs auto 0 0

# Trigger mounting
$ sudo mount -a

# Or manually mount in cli
$ sudo mount (-t nfs -o rw) 192.168.1.140:/home/rh/workspace \
$     /home/rh/workspace/ser140/workspace

# Issue: macOS: Operation not permitted
#	-o resvport, explicilty use privileged port. Linux doesn't have this problem cause it 
#	uses priviledged port by default.
$ sudo mount -o resvport ...
```

## Refs

- Ubuntu's NFS guide. https://help.ubuntu.com/lts/serverguide/network-file-system.html.en.
- `man 5 exports`. http://man7.org/linux/man-pages/man5/exports.5.html.
- macOS X Mount NFS Share / Set and NFS Client. https://www.cyberciti.biz/faq/apple-mac-osx-nfs-mount-command-tutorial/.
- Why does mounting and NFS share from linux require the use of a provileged port? https://apple.stackexchange.com/questions/142697/why-does-mounting-an-nfs-share-from-linux-require-the-use-of-a-privileged-port.