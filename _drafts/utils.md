# Utils


## Common Commands

```bash
apropos sth
man [section] sth
grep [OPTIONS] [-e PATTERN | -f FILE] [FILE...]

# check distribution
# universal
cat /etc/os-release
# debian
cat /etc/debian_version
# ubuntu
lsb_release
cat /etc/lsb_release
# redhat or centos
cat /etc/redhat-release
cat /etc/centos-release
# count lines of a project
find . -name '*.[h|c]' | xargs wc -l
```


## Process

```bash
ps
jobs
# try kill pid
pkill -9 [fname]
# equals to
pgrep [fname] | xargs kill -9
# or equals to
ps -ef | grep [fname] | awk '{print $2}' | xargs kill -9
```


## Memory

```bash
free
```

## FS

```bash
parted
df
fdisk
fscheck
```

## Network

```bash
# iproute2 tools
iptables
tc
iptraf
```

## Linux Performance
See [Linux Performance](http://www.brendangregg.com/linuxperf.html).


## Linux Tracer
See [Choosing a Linux Tracer](http://www.brendangregg.com/blog/2015-07-08/choosing-a-linux-tracer.html)
