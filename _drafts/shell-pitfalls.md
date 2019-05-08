# Shell Pitfalls

写过一个脚本，里面包含了一下命令：

```bash
$ LD_PRELOAD=libvma.so netperf ...
```

意思先设置一个环境变量 LD_PRELOAD，然后运行 netperf 程序，它是可以正常工作的。写一个等价的命令模拟这个过程：

```bash
$ FOO=bar echo $FOO

```

输出却是空，而不是期望的 bar。`set -x` 得出 shell 执行过程：

```bash
$ (set -x; FOO=bar echo $FOO)
+ FOO=bar
+ echo

```

我们的 `echo $FOO` 变成了 `echo`，环境变量 `FOO` 消失了？所以，我们有理由相信，shell 在解释脚本时不会实时更新全局环境变量表，但会在新 fork 出的进程中使用更新后的环境变量表：

```bash
$ (set -x; FOO=bar bash -c 'echo $FOO')
+ FOO=bar
+ bash -c 'echo $FOO'
bar
```

需要注意的是，`-c` 参数要用 `'` 而不是 `"`，否则 shell 仍然会在当前上下文中展开 `$FOO`。

P.S. shell 提供 `export` 语法让我们可以更新当前上下文的环境变量表。


## Refs

- Why is setting a variable before a command legal in bash? https://unix.stackexchange.com/questions/126938/why-is-setting-a-variable-before-a-command-legal-in-bash.