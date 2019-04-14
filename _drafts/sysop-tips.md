# Tips on (Frequent) System Operation
TBC

## General
```bash
# Search the whatis database for strings
$ apropos keyword ...

# Search in manpage
$ man [section] keyword

# Ctrl+D to search used commands in reverse
```

## Show concerned infomation
```bash
# Of kernel infomation
$ uname -a

# Of only kernel version
$ uname -r

# Of distribution-specific information
# @ubuntu
$ cat /etc/os-release

# @redhat/centos
cat /etc/redhat-release
cat /etc/centos-release

# Show businfo (e.g. pci number) of devices of specific classification
$ lshw -businfo -c network
```

## Network
```bash
# Use ss@iproute2 to list TCP/IPv4 listening sockets,
#   -t, display tcp sockets
#   -l, display only listening sockets
#   -n, dont try to resolve service names that may make it runs faster
#   -4, display only IPv4 sockets
$ ss -tln4

# On macOS, we can use `lsof` instead,
#   -n, inhibiting conversion from network numbers to host names may make lsof run faster
#   -P, inhibiting the conversion of port numbers to port names
#   -i4, IPv4
$ lsof -nP -i4 | grep LISTEN

# List all rules in the selected chain (default all) in the selected table (default INPUT)
#   -n, wont resolve hostname, network names, or services
iptables -t [NAT] -L [chain] -v -n
```

## Process
```bash
# Lookup and kill processes based on name and other attributes,
#   -9, KILL (non-catchable, non-ignorable kill)
$ pkill -9 keyword
# or
$ pgrep keyword | xargs kill -9
# or
$ ps -ef | grep keyword | awk '{print $2}' | xargs kill -9
```

## Storage and file system
```bash
# Format a block device
$ parted -a optimal /dev/sdc

# Report file system disk usage in human-readable format
$ df -h [file_to_report]
```
