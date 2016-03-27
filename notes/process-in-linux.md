# Process in Linux
进程定义为程序执行的实例。操作系统需要借助它保存正在执行的程序的实时数据。


## Memory Architecture of Process

### Paging
Linux采用四级分页模型（PGD, [PUD, PMD,] PT)。其中页大小取决于线性地址中的offset位数，典型的，Linux使用12bits，即页大小为4KB。

### Setup Memory
Linux启动过程中，借住BIOS构建物理地址映射。内核代码（text）、数据（data）占据物理内存前3MB RAM（包括保留空间）。
线性地址以0xc0000000分界，低地址为内核态进程可寻址空间。内核创建并维护自己的页表（master kernel PGD)。
借助这些页中的数据，内核便可进行线性地址到物理地址的转换。

### Allocating the Process Descriptor

### Try to Trace Process Kernel Stack


## Process Descriptor
这里简单的看一看 `task_struct`. 可以认为以下是进程管理所需要的基本元素。

### State

```c
/* bitmask of tsk->state */
#define TASK_RUNNING		0
#define TASK_INTERRUPTIBLE	1
#define TASK_UNINTERRUPTIBLE	2
#define __TASK_STOPPED		4
#define __TASK_TRACED		8

#define TASK_DEAD		64
#define TASK_WAKEKILL		128
#define TASK_WAKING		256
#define TASK_STATE_MAX		512

/* bitmask of tsk->exit_state */
#define EXIT_ZOMBIE		16
#define EXIT_DEAD		32
```
- `TASK_RUNNING`: 进程是可执行的；它或者执行，或者等待执行。
- `TASK_INTERRUPTIBLE`: 进程正在睡眠，即被阻塞，等待某些条件的达成。
- `TASK_UNINTERRUPTIBLE`: 进程不对信号做响应。这个状态通常在进程必须在等待时不受干扰或等待时间就会发生时出现。
- `__TASK_STOPPED`: 进程停止执行。e.g. 接收到 `SIGSTOP`, `SIGTSTP`, `SIGTTIN`, `SIGTTOU`; debugging 期间接受到任何信号。
- `__TASK_TRACED`: 被其他进程跟踪的进程。e.g. 通过 ptrace 对调试程序进行跟踪。
- `EXIT_ZOMBIE`: 进程执行被终止，但是，父进程还没有发布 `wait4()` 或 `waitpid()` 系统调用来
返回有关死亡进行的信息。
- `EXIT_DEAD`: 最终状态，由于父进程刚发出 `wait4()` or `waitpid()` 系统调用，因而进程由系统删除。

```c
/* state variable in `task_struct` */

volatile long state;	/* -1 unrunnable, 0 runnable, >0 stopped */
int exit_state;
```

### Relationships Among Processes
Linux 系统的进程之间存在一个明显的进程关系。

```
/* 
 * Pointers to (original) parent process, youngest child, younger sibling,
 * older sibling, respectively.  (p->father can be replaced with 
 * p->real_parent->pid)
 */
struct task_struct *real_parent; /* real parent process */
struct task_struct *parent; /* recipient of SIGCHLD, wait4() reports */
struct list_head children;	/* list of my children */
struct list_head sibling;	/* linkage in my parent's children list */
struct task_struct *group_leader;	/* threadgroup leader */
```

- `real_parent`: 指向创建了P的进程的描述符，如果P的父进程不存在，就指向进程1（init）的描述符。
- `parent`: 指向P的当前父进程（子进程终止时必须向其发信号）。一般，该值与`real_parent`一致，
但偶尔也有不同，e.g. 某进程ptrace进程P。
- `children`: 链表对头部，链表中的所有元素都是P创建的子进程。
- `sibling`: 指向兄弟进程链表中的下一个（前一个）的指针，这些兄弟进程的父进程为P。
- `group_leader`: 指向P所在线程组领头线程的描述符。

>特别的，一个进程可能是一个进程组或者登录会话的领头进程，也可能是一个线程组的领头进程，它还可以跟踪其他进程的执行。		*《深入理解 LINUX 内核 第三版》P.96*

### PID
PID 用于标示进程。它在`task_struct`中的相关变量:

```c
pid_t pid;
pid_t tgid;
```

- `tgid`: Thread Group ID, 该P所在线程组中第一个LWP的PID。一般进程只有一个线程，`tgid`与`pid`
相同。`getpid()`返回`tgid`的值。

>由于循环使用 PID 编号，内核必须通过管理一个pidmap-array位图来表示当前已分配的PID号和闲置的PID号。因为一个页框包含32768个位，所以32位体系结构中pidmap-array位图存放在一个单独的页中。。。			*《深入理解 LINUX 内核 第三版》P.88-89*

```c
/* linux/types.h */
typedef struct {
	volatile int counter;
} atomic_t;

/* include/linux/pid_namespace.h */
struct pidmap {
       atomic_t nr_free;
       void *page;
};

#define PIDMAP_ENTRIES         ((PID_MAX_LIMIT + 8*PAGE_SIZE - 1)/PAGE_SIZE/8)

struct pid_namespace {
	struct kref kref;
	struct pidmap pidmap[PIDMAP_ENTRIES];
	int last_pid;
	struct task_struct *child_reaper;
	struct kmem_cache *pid_cachep;
	unsigned int level;
	struct pid_namespace *parent;
};
```

Related source files:
- include/linux/pid_namespace.h
- include/linux/pid.h
- kernel/pid_namespace.c
- kernel/pid.c


## `thread_info`
内核将笨重且须频繁修改的`task_struct`丢在动态内存中，而在内核的内存区维护一个简洁的`thread_info`（52Byte），它存有指向`task_struct`的指针。内核将`thread_info`和当前进程的内核栈绑在一起（丢在两个连续的页中，`thread_info`从低地址开始，而栈开始于高地址）。这样，内核可以借助esp快速获取`task_struct`的指针（屏蔽esp的低位可获得当前所分配页的低地址，即`thread_info`的地址）。current宏工作方式就是如此：

```c
/* x86/include/asm/page_32_type.h */
#ifdef CONFIG_4KSTACKS
#define THREAD_ORDER	0
#else
#define THREAD_ORDER	1
#endif
#define THREAD_SIZE 	(PAGE_SIZE << THREAD_ORDER) /* PAGE_SIZE = 2^12 in 4KB PAGE. THREAD_SIZE = 2^13 for 8KBSTACKS */

/* asm-generic/current.h */
#define get_current() (current_thread_info()->task)
#define current get_current()

/* x86/include/asm/thread_info.h */
/* how to get the current stack pointer from C */
register unsigned long current_stack_pointer asm("esp") __used;

/* how to get the thread information struct from C */
static inline struct thread_info *current_thread_info(void)
{
	return (struct thread_info *)
		(current_stack_pointer & ~(THREAD_SIZE - 1)); /* ~(THREAD_SIZE - 1) = 0xfffff000 */
}
```

`%esp`与0xfffff000后便是`thread_info`的地址。

## References
1. Daniel P. Bovet, Marco Cesati. Understanding the Linux Kernel, 3rd Edition.
2. Robert Love. Linux Kernel Development, 3rd Edition.