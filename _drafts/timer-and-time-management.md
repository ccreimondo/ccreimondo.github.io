# Timer and Time Management in Linux
内核需要周期性地：
- 更新自系统启动以来所经过的时间
- 更新时间和日期
- 确定进程在每个CPU上已运行的时间，如果超过已分配的时间片，则抢占。
- 更新资源使用统计
- 检查每个软定时器的时间间隔是否已到


## Files Related
- `linux/jiffies.h`
- `linux/time.h`
- `linux/timer.h`
- `kernel/time.c`
- `kernel/timer.c`
- `kernel/time/timekeeping.c`
- `seqlock.h`


## Real-Time Clock and System Timer
- RTC为独立硬件，用于维护时间。
- System Timer用于定期产生全局时钟中断。


## Real-Time Clock
>The real-time clock (RTC) provides a nonvolatile device for storing the system time. On boot, the kernel reads the RTC and uses it to initialize the wall time, which is stored in the xtime variable.

### The Time of Day

```c
/* linux/time.h */
#ifndef _STRUCT_TIMESPEC
#define _STRUCT_TIMESPEC
struct timespec {
	__kernel_time_t	tv_sec;			/* seconds */
	long		tv_nsec;		/* nanoseconds */
};
#endif

struct timeval {
	__kernel_time_t		tv_sec;		/* seconds */
	__kernel_suseconds_t	tv_usec;	/* microseconds */
};

struct timezone {
	int	tz_minuteswest;	/* minutes west of Greenwich */
	int	tz_dsttime;	/* type of dst correction */
};

/* 
 * Current datetime (seconds since midnight 1970 UTC, nanoseconds
 * since last second).
 */
extern struct timespec xtime;	

/* 
 * Time since we booted, not including time spent in suspend.
 */
extern struct timespec wall_to_monotonic;
```

#### Initialize
`time_init()`->`get_cmos_time()`->init `xtime` and `wall_to_monotonic`

#### Update
pass


## System Timer

### tick, `HZ` and `jiffies`
tick是内核连续两次时钟中断（由系统定时器周期性产生 e.g. PIT）的间隔（时间？）。全局变量`jiffies`用来记录自系统启动以来产生的tick的总数。内核中的`HZ`是tick rate，time(tick)=1/(tick_rate)。

#### What's `jiffies_64`?
`jiffies_64` extends `jiffies` from 32bit to 64bit. And there's not wrapround in an expected time.

```c
/* linux/jiffies.h */
extern u64 __jiffy_data jiffies_64;
extern unsigned long volatile __jiffy_data jiffies;

#if (BITS_PER_LONG < 64)
u64 get_jiffies_64(void);
#else
static inline u64 get_jiffies_64(void)
{
	return (u64)jiffies;
}
#endif

/* kernel/time.c */
#if (BITS_PER_LONG < 64)
u64 get_jiffies_64(void)
{
	unsigned long seq;
	u64 ret;

	do {
		seq = read_seqbegin(&xtime_lock);
		ret = jiffies_64;
	} while (read_seqretry(&xtime_lock, seq));
	return ret;
}
EXPORT_SYMBOL(get_jiffies_64);	/* EXPORT_SYMBOL: defined in linux/module.h */
#endif
```

### `jiffies` Wrapround and Macros for Time Comparing

```c
/* linux/jiffies.h */
#define time_after(a,b)		\
	(typecheck(unsigned long, a) && \
	 typecheck(unsigned long, b) && \
	 ((long)(b) - (long)(a) < 0))
#define time_before(a,b)	time_after(b,a)
```
`time_after(a,b)`表示a超过b时，返回真，否则返回假。该宏可以解决`jiffies`wrapround而导致错误比较结果的问题。unsigned integer to signed的转换如图（CSAPP.Figure.2.17）：
![CSAPP.Figure.2.17](assets/csapp-figure-2-17.png)

考虑这样一段代码

```c
unsigned long timeout = jiffies + HZ/2;  /* 0.5s 后超时 */

/* do something...*/

if (time_after(jiffies, timeout)) {
	/* timeout: error occured... */
} else {
	/* no timeout... */
}
```

根据上图，若`timeout < 2^w`，`jiffies`递增至大于`timeout`且溢出，则`jiffies`必定属于[0, 2^(w-1)]。`timeout`和`jiffies`从`unsigned long`转换成`long`后，逻辑上的大小关系仍然成立，即`jiffies > timeout`。`time_before`宏成功解决了`jiffies`的wrapround。但若初始时`timeout < 2^(w-1)`，`jiffies`递增后大于2^(w-1)，`time_before`带来的结果是`false`，即`jiffies < timeout`，好像哪里不对？

### The Timer Interrupt Handler

#### `setup_irq(0, &irq0)`
TODO

#### `timer_interrupt()`
- `make_offset()`:

#### `do_timer_interrupt()`
- `jiffies_64++`
- `update_times()`: update system datetime.
- `update_process_times()`: accounting.
- `profile_tick()`:
- `set_rtc_mmss()`: if clock source is from outer.

#### 更新本地CPU统计数

```c
/* kenerl/timer.c */
void update_process_times(int user_tick)
{
	struct task_struct *p = current;
	int cpu = smp_processor_id();

	/* Note: this timer irq context must be accounted for as well. */
	account_process_tick(p, user_tick);
	run_local_timers();
	rcu_check_callbacks(cpu, user_tick);
	printk_tick();
	scheduler_tick();
	run_posix_cpu_timers(p);
}
```

>update_curr() is invoked periodically by the system timer and also whenever a process becomes runnable or blocks, becoming unrunnable. 

那么，是这里某个函数调用的吗？`scheduler_tick()`->update_rq_clock(rq)->`rq->clock_task`<-`update_curr()`。


#### Sequential Lock vs Read-Write Spin Locks
关于`seq`的引入，`linux/seqlock.h`开头有一段很清楚的注释。在`seq`中，写者可以随时获得锁来写入数据，即不会饥饿。而在`rwspinlock`中，writer需要等待持有`rwlock`的readers释放`rwlock`。那么为什么？有如下代码：

```c
/* linux/compiler.h
 *
 * Prevent the compiler from merging or refetching accesses.  The compiler
 * is also forbidden from reordering successive instances of ACCESS_ONCE(),
 * but only when the compiler is aware of some particular ordering.  One way
 * to make the compiler aware of ordering is to put the two invocations of
 * ACCESS_ONCE() in different C statements.
 *
 * This macro does absolutely -nothing- to prevent the CPU from reordering,
 * merging, or refetching absolutely anything at any time.  Its main intended
 * use is to mediate communication between process-level code and irq/NMI
 * handlers, all running on the same CPU.
 */

#define ACCESS_ONCE(x) (*(volatile typeof(x) *)&(x))

/* linux/seqlock.h
 *
 * Expected reader usage:
 * 	do {
 *	    seq = read_seqbegin(&foo);
 * 	...
 *      } while (read_seqretry(&foo, seq));
 *
 */

typedef struct {
	unsigned sequence;
	spinlock_t lock;
} seqlock_t;

/* Lock out other writers and update the count.
 * Acts like a normal spin_lock/unlock.
 * Don't need preempt_disable() because that is in the spin_lock already.
 */
static inline void write_seqlock(seqlock_t *sl)
{
	spin_lock(&sl->lock);
	++sl->sequence;
	smp_wmb();
}

static inline void write_sequnlock(seqlock_t *sl)
{
	smp_wmb();
	sl->sequence++;
	spin_unlock(&sl->lock);
}

static inline int write_tryseqlock(seqlock_t *sl)
{
	int ret = spin_trylock(&sl->lock);

	if (ret) {
		++sl->sequence;
		smp_wmb();
	}
	return ret;
}

/* Start of read calculation -- fetch last complete writer token */
static __always_inline unsigned read_seqbegin(const seqlock_t *sl)
{
	unsigned ret;

repeat:
	ret = ACCESS_ONCE(sl->sequence);
	if (unlikely(ret & 1)) {
		cpu_relax();
		goto repeat;
	}
	smp_rmb();

	return ret;
}

/*
 * Test if reader processed invalid data.
 *
 * If sequence value changed then writer changed data while in section.
 */
static __always_inline int read_seqretry(const seqlock_t *sl, unsigned start)
{
	smp_rmb();

	return (sl->sequence != start);
}
```

readers`read_seqbegin`只读取`sequence`值，不会持有`spinlock`。`spinlock`只用于writers之间。readers通过比对前后`sequence`来确定要读的数据是否有修改，不同就再一次（循环）。其中，在`read_seqbegin`中，`unlikely(ret & 1)`表示要访问的数据正在被writer修改。`sequence`（default=0，writer写前`++sequence`，写完后`++sequence`）如果是奇数，表示writer正在进行数据修改，如果是偶数，表示没writer进行数据修改操作。上述源码中，还有一个`smp_wmb`(Symmetric Multprocessing, Write Memory Barrier)和`smp_rmb`(...Read Memory Barrier)。什么是Memory Barrier？为什么需要内存屏障？`rmb`和`wmb`有什么区别？基本的，屏障用于保证程序按序执行（即在该处之前、之后两个地方有关内存读取操作的汇编指令不能被混在一起），有Memory Barrier和编译器Barrier之分，分别对应于`mb()`和`barrier()`。`mb()`除了禁止编译器对指令的顺序优化，还可以保证处理器的数据载入和存储操作指令都不会跨越屏障重新排序（分开的实现分别对应于`rmb()`和`wmb()`）。`barrier()`方法只可以防止编译起对载入或者存储操作进行优化（调整顺序）。程序为什么会在处理器上乱序执行？在编译阶段，编译器可能重新安排汇编语言指令以使寄存器以最优的方式使用。同时，现代处理器通常会并行地执行若干条指令（Pipelining）。它们会优化到何种尺度？而barrier具体又是如何实现的？TODO


## Soft Timers
详见ULK.CH6.软定时器。它们由TIMER_SOFTIRQ软中断执行。


## Related System Calls
用户态下的进程通过gettimeofday()读取时间和日期。


## How does command `time` calculate time (user、system)?
TODO


## References
- Robert Love. Linux Kernel Development, 3rd Edition.
- [http://www.fieldses.org/~bfields/kernel/time.txt](http://www.fieldses.org/~bfields/kernel/time.txt)
