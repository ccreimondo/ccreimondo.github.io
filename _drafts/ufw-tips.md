# Tips on UFW

正常情况下，使用 UFW 的姿势是：

1. 添加规则，`ufw add ...`
2. 重启 UFW，`sudo ufw disable && sudo ufw enable`

然后，如果发现无链接服务器，有如下可能：

1. 检查防火墙规则中是否允许 SSH 连接，`sudo ufw status verbose`
2. 检查 iptables filter 表中是否添加了 UFW primary chains，以 INPUT 为例（其它还有FORWARD 和 OUTPUT），`iptables -L INPUT -v -n -t filter` 输出中应该有若干前缀为 ufw- 的规则，如下图。否则按照套路二重启 UFW。

```
sudo iptables -L INPUT -v -n -t filter 
Chain INPUT (policy DROP 91 packets, 4269 bytes)
 pkts bytes target     prot opt in     out     source               destination         
16902 2134K ufw-before-logging-input  all  --  *      *       0.0.0.0/0            0.0.0.0/0           
16902 2134K ufw-before-input  all  --  *      *       0.0.0.0/0            0.0.0.0/0           
 1924  115K ufw-after-input  all  --  *      *       0.0.0.0/0            0.0.0.0/0           
   91  4269 ufw-after-logging-input  all  --  *      *       0.0.0.0/0            0.0.0.0/0           
   91  4269 ufw-reject-input  all  --  *      *       0.0.0.0/0            0.0.0.0/0           
   91  4269 ufw-track-input  all  --  *      *       0.0.0.0/0            0.0.0.0/0
```

套路二：

```bash
# Tricky restart
sudo ufw disable
sudo /lib/ufw/ufw-init flush-all
sudo ufw enable
```

根据 [UFW manpage](http://manpages.ubuntu.com/manpages/xenial/man8/ufw-framework.8.html)，flush-all 将删除 iptables 中所有的 chains 并将 policy 重置为 ACCEPT。

注意：该方式没法和其他会修改 iptables 的应用共存，如 docker，因为 flush-all 会重置 iptables。

## Refs

1. Official documentation. https://help.ubuntu.com/16.04/serverguide/firewall.html.
2. UFW manpages. http://manpages.ubuntu.com/manpages/xenial/man8/ufw-framework.8.html.