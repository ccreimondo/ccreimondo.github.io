# Daily Use of Linux with CLI

## File Operations

```bash
```

## Ultimate Process Command

```bash
pkill -9 [fname]
# equal to
pgrep [fname] | xargs kill -9

ps -ef | grep [fname] | awk '{print $2}' | xargs kill -9
# equal to
```


## Check Linux Distribution

```bash
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
```


## References
- [Debian Official Wiki](https://wiki.debian.org)
- [CentOS](http://www.centos.org/docs/5/html/5.2/Deployment_Guide/)
