# Timer and Time Management in Linux

## Real-Time Clock and System Timer
pass

## Real-Time Clock
pass
### The Time of Day
pass

## System Timer
pass
### tick, `HZ` and `jiffies`
tick是内核连续两次时钟中断（由系统定时器周期性产生 e.g. PIT）的间隔（时间？）。全局变量`jiffies`用来记录自系统启动以来产生的tick的总数。内核中的`HZ`是tick rate，time(tick)=1/(tick_rate)。

### Time Compare
```c
// in include/linux/jiffies.h
#define time_after(a,b)		\
	(typecheck(unsigned long, a) && \
	 typecheck(unsigned long, b) && \
	 ((long)(b) - (long)(a) < 0))
#define time_before(a,b)	time_after(b,a)
```
`time_after(a,b)`表示a超过b时，返回真，否则返回假。该宏可以解决`jiffies`wrapround而导致错误比较结果的问题。编译器对(long)(unsgined long)的默认行为如图：(TODO)

### The Timer Interrupt Handler
pass

## Timers
pass

## There're some collaborations between RTC and System Timer?
pass

## How does command `time` calculate time（user、system）?
pass

## References
- Robert Love. Linux Kernel Development, 3rd Edition.