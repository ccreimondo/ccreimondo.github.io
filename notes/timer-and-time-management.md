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
`time_after(a,b)`表示a超过b时，返回真，否则返回假。该宏可以解决`jiffies`wrapround而导致错误比较结果的问题。unsigned integer to signed的转换如图（CSAPP.Figure.2.17）：
![CSAPP.Figure.2.17](http://blog.reimondo.org/images/blog/csapp-figure-2-17.png)
考虑这样一段代码
```c
unsigned long timeout = jiffies + HZ/2;  /* 0.5s 后超时 */

/* do something...*/

if (time_before(jiffies, timeout)) {
	/* no timeout... */
} else {
	/* timeout: error occured... */
}
```
根据上图，若`timeout < 2^w`，`jiffies`递增至大于`timeout`且溢出，则`jiffies`必定属于[0, 2^(w-1)]。`timeout`和`jiffies`从`unsigned long`转换成`long`后，逻辑上的大小关系仍然成立，即`timeout < jiffies`。`time_before`宏成功解决了`jiffies`的wrapround。但若初始时`timeout < 2^(w-1)`，`jiffies`递增后大于2^(w-1)，`time_before`带来的结果是`false`，即`jiffies < timeout`，好像哪里不对？

### The Timer Interrupt Handler
pass

## Timers
pass

## There're some collaborations between RTC and System Timer?
pass

## How does command `time` calculate time (user、system)?
pass

## References
- Robert Love. Linux Kernel Development, 3rd Edition.