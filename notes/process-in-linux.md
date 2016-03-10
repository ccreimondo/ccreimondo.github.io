# Process in Linux
进程定义为程序执行的实例。操作系统需要借助它保存正在执行的程序的实时数据。

## Memory Architecture of Process
### Paging
Linux 采用四级分页模型 (PGD, [PUD, PMD,] PT)。 其中 Page Size 取决于线性地址中的 offset 位数，典型的，Linux 使用 12bits，即页大小为 4KB。
### Setup Memory
Linux 启动过程中，借住 BIOS 构建物理地址映射。内核代码（text）、数据（data）占据物理内存前 3MB RAM（包括保留空间）。线性地址以 0xc0000000 分界，低地址为内核态进程可寻址空间。内核创建并维护自己的页表（master kernel PGD)。借助这些页中的数据，内核便可进行线性地址到物理地址的转换。
### Allocating the Process Descriptor
### Try to Trace Process Kernel Stack

## Process-covered Files

## Process Descriptor
这里简单的看一看 `task_struct`. 可以认为这些是进程管理所需要的基本元素。
### State
bitmask of tsk->state:
```c
#define TASK_RUNNING		0
#define TASK_INTERRUPTIBLE	1
#define TASK_UNINTERRUPTIBLE	2
#define __TASK_STOPPED		4
#define __TASK_TRACED		8

#define TASK_DEAD		64
#define TASK_WAKEKILL		128
#define TASK_WAKING		256
#define TASK_STATE_MAX		512
```
- `TASK_RUNNING`: 进程是可执行的；它或者执行，或者等待执行。
- `TASK_INTERRUPTIBLE`: 进程正在睡眠，即被阻塞，等待某些条件的达成。
- `TASK_UNINTERRUPTIBLE`: 进程不对信号做响应。这个状态通常在进程必须在等待时不受干扰或等待时间就会发生时出现。
- `__TASK_STOPPED`: 进程停止执行。e.g. 接收到 `SIGSTOP`, `SIGTSTP`, `SIGTTIN`, `SIGTTOU`; debugging 期间接受到任何信号。
- `__TASK_TRACED`: 被其他进程跟踪的进程。e.g. 通过 ptrace 对调试程序进行跟踪。
bitmask of tsk->exit_state:
```c
#define EXIT_ZOMBIE		16
#define EXIT_DEAD		32
```
- `EXIT_ZOMBIE`: 进程退出时的状态。处于该状态的该进程将不被调度。
- `EXIT_DEAD`:
state variable in `task_struct`:
```c
volatile long state;	/* -1 unrunnable, 0 runnable, >0 stopped */
```
关于 volatile, Documentation/volatile-considered-harmful.txt 里面有这样的描述:
>C程序员通常认为volatile表示某个变量可以在当前执行的线程之外被改变；因此，在内核
>中用到共享数据结构时，常常会有C程序员喜欢使用volatile这类变量。换句话说，他们经
>常会把volatile类型看成某种简易的原子变量，当然它们不是。。。

### Relationships Among Processes
### PID

## References
1. Daniel P. Bovet, Marco Cesati. Understanding the Linux Kernel, 3rd Edition.
