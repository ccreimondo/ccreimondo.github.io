Inputs
===

##Ultimate Process Command
```
pkill -9 [fname]
# Equal to
pgrep [fname] | xargs kill -9

ps -ef | grep [fname] | awk '{print $2}' | xargs kill -9
# Equal to
```

##Find Linux Distribution
```
# Universal
cat /etc/os-release

# Debian
cat /etc/debian_version

# Ubuntu
lsb_release
cat /etc/lsb_release

# Redhat|CentOS
cat /etc/redhat-release
cat /etc/centos-release
```

##Linux Help
- [Debian official wiki](https://wiki.debian.org)
- [CentOS](http://www.centos.org/docs/5/html/5.2/Deployment_Guide/)
