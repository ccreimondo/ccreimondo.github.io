# Creating Processes
用户在终端里选择选择一个刚编译好的程序并按下回车的时候会发生什么？这篇笔记解决如下问题：
- 可执行程序文件的构成
- 进程与线程的创建
- 内核线程的创建


## Files Related
- kernel/fork.c: `do_fork()` & `copy_process()`
- x86/kernel/syscall_table_32.S: syscall_table
- x86/kernel/process_32.c: `__switch_to()` & `sys_clone()` & `sys_execve()` 
- x86/kernel/process_64.c: `sys_clone()`
- x86/kernel/process.c: `sys_fork()`


## Submit a Task
TODD


## `clone()` and `sys_clone()`
`clone()`指glibc封装的syscall，用于创建轻量级进程，`sys_clone()`是clone系统调用的内核实现函数。在参数上，sys_clone没有了clone中的fn、arg参数。sys_clone作为内核例程只需要相应的参数为新子进程分配必要的资源（PID、进程描述符、thread_info等内核数据结构）并丢到相应的队列，这些参数为FLAGS、子进程在用户空间的SP。


## `fork()`->`sys_fork()`->`do_fork()` vs `fork()`->`clone()`->`sys_clone()`->`do_fork()`

```c
int sys_fork(struct pt_regs *regs)
{
	return do_fork(SIGCHLD, regs->sp, regs, 0, NULL, NULL);
}

int sys_clone(struct pt_regs *regs)
{
	unsigned long clone_flags;
	unsigned long newsp;
	int __user *parent_tidptr, *child_tidptr;

	clone_flags = regs->bx;
	newsp = regs->cx;
	parent_tidptr = (int __user *)regs->dx;
	child_tidptr = (int __user *)regs->di;
	if (!newsp)
		newsp = regs->sp;
	return do_fork(clone_flags, newsp, regs, 0, parent_tidptr, child_tidptr);
}
```

sys_fork和sys_clone最终都是调用do_fork且do_fork基本复制了sys_clone或者sys_fork的参数（do_fork的第4个参数stack_size未使用，总是被设置为0），因此sys_clone完全可以替代sys_fork。事实上，在Linux中，fork就是通过调用clone来完成进程创建的。

- 线程创建：clone(..., CLONE_VM | CLONE_FS | CLONE_FILES | CLONE_SIGHAND, 0,...)，这些FLAGS分别指明父子进程共享地址空间、文件系统资源、文件描述符和信号处理函数。
- 进程创建：clone(..., SIGCHLD, 0,...)


## `do_fork()` & `copy_process()`
pass


## `exec()` & `sys_execve()`
pass


## `kernel_thread()`
pass


## `exit_group()` & `exit()`
pass


## `do_group_exit()` & `do_exit()`
pass