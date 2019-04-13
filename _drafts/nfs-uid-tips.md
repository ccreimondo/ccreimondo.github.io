# Unified User Management Among Number of Nodes (Proposal)

## Background & Motivation

目前，存储系统是以 NFS（Networked File System）的形式挂载在所有计算机节点和管理节点的 /datapool 目录上。在多节点上共享一个 NFS 存在一个问题：当在节点 A 上以 user 用户在 NFS 中创建一个文件 file0 时，file0 在节点 B 上的 owner 可能不再是 user，也就无法在节点 B 上是用 user 用户访问 file0。

Linux 中，我们创建一个 user 用户时，系统会为其分配一个 [UID（group 对应 GID）](https://en.wikipedia.org/wiki/User_identifier)。当一个文件被创建时，文件系统只记录 owner 的 UID 和 GID 而非 username。所以，在不同的节点上，即使 username 相同，若 UID 不同，则拒绝访问（see `man -s 2 access` for more details）。

所以，解决该问题的基本思路就是统一所有节点上 username、groupname 和 UID、GID 的对应表。方案有两个：

1. 划分一段 UID、GID 分配给需要全局使用的帐号，然后同时在所有机器上创建新账户；
2. 使用中心化的帐号管理服务，如 freeIPA。但该[服务配置](https://www.digitalocean.com/community/tutorials/how-to-configure-a-freeipa-client-on-ubuntu-16-04/)有点复杂，参见 [FreeIPA's Deployment Recommendations](https://www.freeipa.org/page/Deployment_Recommendations)（麻烦在需要构建和维护私有 DNS 和配置 replicas）。

考虑到数据平台目前所用全局帐号很明确（user、charles），且在可见的未来变化不大，故这里直接采用方案一，简单高效。

## Implementation

Linux 关于 UID 的使用没有统一的规范，但有一些约定（refer to /etc/login.defs @Ubuntu 18.04）：

```bash
# ...
#
# Min/max values for automatic uid selection in useradd
#
UID_MIN		1000
UID_MAX		60000
# System accounts
SYS_UID_MIN	100
SYS_UID_MAX	999
#
# Min/max values for automatic gid selection in groupadd
#
GID_MIN		1000
GID_MAX		60000
# System accounts
SYS_GID_MIN	100
SYS_GID_MAX	999
# ...
```

当然，创建账户推荐 `useradd` 的 wrapper `adduser` 工具。`adduser` 有自己的配置文件 `/etc/adduser.conf`，其使用 UID 和 GID 的约定如下：

```bash
# ...
# FIRST_SYSTEM_[GU]ID to LAST_SYSTEM_[GU]ID inclusive is the range for UIDs
# for dynamically allocated administrative and system accounts/groups.
# Please note that system software, such as the users allocated by the base-password
# package, may assume that UIDs less than 100 are unallocated.
FIRST_SYSTEM_UID=100
LAST_SYSTEM_UID=999

FIRST_SYSTEM_GID=100
LAST_SYSTEM_GID=999

# FIRST_[GU]ID to LAST_[GU]ID inclusive is the range of UIDs of dynamically
# allocated user accounts/groups.
FIRST_UID=1000
LAST_UID=59999

FIRST_GID=1000
LAST_GID=59999
# ...
```

P.S. System user 和 normal user 是约定，没什么本质区别。

综上，100-999 的 UID/GID 已被划分给 system user，1000-60000 划分给 normal user。所以考虑细分 normal user 的 UID/GID 段。**现将 2000-3000 划分给数据平台全局帐号，其它账户禁止使用该 UID/GID 段**。指定 UID/GID 的相关命令如下：

```bash
# Change UID/GID for existing users
usermod -u $NEW_ID $USERNAME && groupmod -g $NEW_ID $GROUPNAME
# Specify UID/GID when create new accounts
adduser --uid $MY_ID --gid $MY_ID $USERNAME
# Operate accross number of nodes simutaneously
TARGETS=(d0 c0 c1 c2 c3); && \
su - root -c "for T in $TARGETS; do ssh $T 'usermod -u 2001 user && groupmod -g 2001 user'; done "
```

## References

- [How to Change a USER and GROUP ID on Linux For All Owned Files](https://www.cyberciti.biz/faq/linux-change-user-group-uid-gid-for-all-owned-files)

