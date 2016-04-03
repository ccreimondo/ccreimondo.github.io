# Creating Processes
用户在终端里选择选择一个刚编译好的程序并按下回车的时候会发生什么？这篇笔记解决如下问题：
- 可执行程序文件的构成
- 进程与线程的创建
- 内核线程的创建


## Files Related
- `kernel/fork.c`: `do_fork()` & `copy_process()`
- `x86/kernel/syscall_table_32.S`:
- `x86/kernel/process_32.c`: `__switch_to()` & `sys_clone()` & `sys_execve()` & `process_32.c`
- `x86/kernel/process.c`: `sys_fork()`


## Submit a Task
- Just in Frontend
- Put in Backend


## `clone()` and `sys_clone()`


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


## `do_fork()` & `copy_process()`


## `exec()` & `sys_execve()`
pass


## `kernel_thread()`


