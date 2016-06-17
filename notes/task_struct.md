# Task Struct
`task_struct`中一些变量的解析。


## Process State

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

/* state variable in `task_struct` */

volatile long state;	/* -1 unrunnable, 0 runnable, >0 stopped */
int exit_state;
```
- `TASK_RUNNING`: 进程是可执行的；它或者执行，或者等待执行。
- `TASK_INTERRUPTIBLE`: 进程正在睡眠，即被阻塞，等待某些条件的达成。
- `TASK_UNINTERRUPTIBLE`: 进程不对信号做响应。这个状态通常在进程必须在等待时不受干扰或等待时间就会发生时出现。
- `__TASK_STOPPED`: 进程停止执行。e.g. 接收到 `SIGSTOP`, `SIGTSTP`, `SIGTTIN`, `SIGTTOU`; debugging 期间接受到任何信号。
- `__TASK_TRACED`: 被其他进程跟踪的进程。e.g. 通过 ptrace 对调试程序进行跟踪。
- `EXIT_ZOMBIE`: 进程执行被终止，但是，父进程还没有发布 `wait4()` 或 `waitpid()` 系统调用来
返回有关死亡进行的信息。
- `EXIT_DEAD`: 最终状态，由于父进程刚发出 `wait4()` or `waitpid()` 系统调用，因而进程由系统删除。


## For Scheduling

```c
int prio, static_prio, normal_prio;
unsigned int rt_priority;
const struct sched_class *sched_class;
struct sched_entity se;
struct sched_rt_entity rt;
```

- static_prio: [0, 99] for rt, [100, 139] for normal task (corrosponding to [-20, 19] in nice). And we can found that real-time tasks always hava high priority than normal tasks.
- prio: dynamic priority for normal tasks, caculated by static_prio and other factors.
- normal_prio: legacy, same as prio.
- rt_priority: dynamic priority for real-time tasks, caculated by static_prio and other factors.

sched_entity、sched_rt_entity是task_struct中用于调度的变量拓展。sched_class中存有
相关调度类的方法。


## Relationships Among Processes
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

特别的，一个进程可能是一个进程组或者登录会话的领头进程，也可能是一个线程组的领头进程，它还可以跟踪其他进程的执行。

## PID
类Unix系统允许用户使用PID标示进程（系统自己用`struct task_struct *`）。PID在`task_struct`中的相关变量:

```c
pid_t pid;
pid_t tgid;
```

- `tgid`: Thread Group ID, 该P所在线程组中第一个LWP的PID。一般进程只有一个线程，`tgid`与`pid`相同。对于一个多线程的进程，每个线程都会分配自己的`pid`，但`tgid`一定相同。`getpid()`返回`tgid`的值。

### `pidmap`

```c
/* linux/types.h */
typedef struct {
	volatile int counter;
} atomic_t;

/* linux/pid_namespace.h */
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

由于循环使用PID编号，内核必须通过管理一个pidmap-array位图来表示当前已分配的PID号和闲置的PID号。因为一个页框包含32768个位，所以32位体系结构中pidmap-array位图存放在一个单独的页中。

### `struct pid_link pids[PIDTYPE_MAX]`

```c
enum pid_type
{
	PIDTYPE_PID,
	PIDTYPE_PGID,
	PIDTYPE_SID,
	PIDTYPE_MAX
};

```

为了快速完成PID->`task_struct`的映射，内核维护了几张哈希表。PID作为key，表值是个`hlink_head`。


## Hardware Context and `struct thread_struct thread`
### Hardare Context
- PC & SP
- GPRs, General Purpose Registers
- FRs, Float Registers
- PCRs, Processor Control Registers (containing information about the CPU state)
- MMRs, Memory Management Registers

###`struct thread_struct thread` in `task_struct`

```c
/* x86/include/asm/processor.h */
struct thread_struct {
	/* Cached TLS descriptors: */
	struct desc_struct	tls_array[GDT_ENTRY_TLS_ENTRIES];
	unsigned long		sp0;
	unsigned long		sp;
#ifdef CONFIG_X86_32
	unsigned long		sysenter_cs;
#else
	unsigned long		usersp;	/* Copy from PDA */
	unsigned short		es;
	unsigned short		ds;
	unsigned short		fsindex;
	unsigned short		gsindex;
#endif
#ifdef CONFIG_X86_32
	unsigned long		ip;
#endif
#ifdef CONFIG_X86_64
	unsigned long		fs;
#endif
	unsigned long		gs;
	/* Hardware debugging registers: */
	unsigned long		debugreg0;
	unsigned long		debugreg1;
	unsigned long		debugreg2;
	unsigned long		debugreg3;
	unsigned long		debugreg6;
	unsigned long		debugreg7;
	/* Fault info: */
	unsigned long		cr2;
	unsigned long		trap_no;
	unsigned long		error_code;
	/* floating point and extended processor state */
	union thread_xstate	*xstate;
#ifdef CONFIG_X86_32
	/* Virtual 86 mode info */
	struct vm86_struct __user *vm86_info;
	unsigned long		screen_bitmap;
	unsigned long		v86flags;
	unsigned long		v86mask;
	unsigned long		saved_sp0;
	unsigned int		saved_fs;
	unsigned int		saved_gs;
#endif
	/* IO permissions: */
	unsigned long		*io_bitmap_ptr;
	unsigned long		iopl;
	/* Max allowed port in the bitmap, in bytes: */
	unsigned		io_bitmap_max;
/* MSR_IA32_DEBUGCTLMSR value to switch in if TIF_DEBUGCTLMSR is set.  */
	unsigned long	debugctlmsr;
	/* Debug Store context; see asm/ds.h */
	struct ds_context	*ds_ctx;
};
```

## context switch & `switch_to`
TODO


## `thread_info`
内核将笨重且须频繁修改的`task_struct`丢在动态内存中，而在内核的内存区维护一个简洁的`thread_info`（52Byte），它存有指向`task_struct`的指针。内核将`thread_info`和当前进程的内核栈（进程的运行需要一个栈来保存参数等信息，处于内核态的进程有自己的内核栈）绑在一起（丢在两个连续的页中，`thread_info`从低地址开始，而栈开始于高地址）。这样，内核可以借助esp快速获取`task_struct`的指针（屏蔽esp的低位可获得当前所分配页的低地址，即`thread_info`的地址）。current宏工作方式就是如此：

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