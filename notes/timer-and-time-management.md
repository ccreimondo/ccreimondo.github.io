# Timer and Time Management in Linux

## Files Related
- `linux/jiffies.h`
- `linux/time.h`
- `linux/timer.h`
- `kernel/time.c`
- `kernel/timer.c`
- `kernel/time/timekeeping.c`
- `seqlock.h`


## Real-Time Clock and System Timer
TODO


## Real-Time Clock
>The real-time clock (RTC) provides a nonvolatile device for storing the system time. On boot, the kernel reads the RTC and uses it to initialize the wall time, which is stored in the xtime variable.

### The Time of Day
#### Variables

```c
/* linux/time.h` */
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
```

#### Initialize
TODO

#### Update
TODO

#### System Call: `gettimeofday()` and `settimeofday()`
TODO


## System Timer
TODO

### tick, `HZ` and `jiffies`
tick是内核连续两次时钟中断（由系统定时器周期性产生 e.g. PIT）的间隔（时间？）。全局变量`jiffies`用来记录自系统启动以来产生的tick的总数。内核中的`HZ`是tick rate，time(tick)=1/(tick_rate)。

#### What's `jiffies_64`?

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
![CSAPP.Figure.2.17](http://blog.reimondo.org/images/blog/csapp-figure-2-17.png)

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
#### Architecture-dependent Routine

#### Architecture-independent Routine

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

readers`read_seqbegin`只读取`sequence`值，不会持有`spinlock`。`spinlock`只用于writers之间。readers通过比对前后`sequence`来确定要读的数据是否有修改，不同就再一次（循环）。其中，在`read_seqbegin`中，`unlikely(ret & 1)`表示要访问的数据正在被writer修改。`sequence`（default=0，writer写前`++sequence`，写完后`++sequence`）如果是奇数，表示writer正在进行数据修改，如果是偶数，表示没writer进行数据修改操作。上述源码中，还有一个`smp_wmb`(Symmetric Multprocessing, Write Memory Barrier)和`smp_rmb`(...Read Memory Barrier)。什么是Memory Barrier？

>内存屏障,也称内存栅栏，内存栅障，屏障指令等， 是一类同步屏障指令，是CPU或编译器在对内存随机访问的操作中的一个同步点，使得此点之前的所有读写操作都执行后才可以开始执行此点之后的操作。语义上，内存屏障之前的所有写操作都要写入内存；内存屏障之后的读操作都可以获得同步屏障之前的写操作的结果。因此，对于敏感的程序块，写操作之后、读操作之前可以插入内存屏障。    See [内存屏障](https://zh.wikipedia.org/wiki/%E5%86%85%E5%AD%98%E5%B1%8F%E9%9A%9C)

为什么需要内存屏障？TODO
那`smp_rmb`和`smp_wmb`有什么区别？TODO


## Timers
TODO


## There're some collaborations between RTC and System Timer?
TODO


## How does command `time` calculate time (user、system)?
TODO


## References
- Robert Love. Linux Kernel Development, 3rd Edition.