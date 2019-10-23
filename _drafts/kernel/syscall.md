# syscall

## Files Related
- `x86/include/asm/unistd_32.h`:
- `x86/entry/calling.`: `.macro SAVE_ALL`
- `linux/linkage.h`: def `ENTRY(name)`
- `x86/kernel/syscall_table_32.S`: def `sys_call_table`
- `kernel/sys.c`: some implementations of syscals
- `x86/kernek/entry_32.S`: contains the system-call and fault low-level handling routines.


## `int $0x80` and `sysenter`
- 封装函数把参数依次放在寄存器上
- 指令触发软中断->系统调用处理程序（system_call）


## `NETRY(system_call)`

```asm
	pushl %eax			# save orig_eax
	SAVE_ALL
	cmpl $(nr_syscalls), %eax
	jae syscall_badsys
syscall_call:
	call *sys_call_table(,%eax,4)
syscall_after_call:
	movl %eax,PT_EAX(%esp)		# store the return value
```
- `pushl %eax`占用一个栈单元，用于保存返回值
- SAVE_ALL将寄存器参数压入内核栈
- 检查系统调用号的合法性（jae=Jump if above or equal）
- `call`根据系统调用号调用相关例程
- 把例程返回值压到第一步占用的栈单元中


## `call *sys_call_table(, %rax, 8)`

- `call`: CPU将当前IP或CS、IP压栈，然后更新CS:IP到指定指令地址
 - call Label: direct
 - call  *Operand: indirect e.g. operand = Imm(, Ei, s) (Ei denotes an arbitrary register i and R[Ei] denotes the value of it. Then, operand value = M[Imm + R[Ei]*s]).
- `call *sys_call_table(, %rax, 8)`: call M[sys_call_table + %rax * 8]. 64Bit系统中，sys_call_table中的表项占用8Byte，故需要将系统调用号（%rax）乘8来获得正确的偏移地址。
- `sys_call_table`: 存有每个系统调用的入口地址。
- 如何查看符号在虚拟内存中的地址？/proc/kallsyms or System.map。


## Reference
- Computer Systems, A Programmer's Perspective, 2nd Edition.
- [System.map. Wikipeida.](https://zh.wikipedia.org/wiki/System.map)
