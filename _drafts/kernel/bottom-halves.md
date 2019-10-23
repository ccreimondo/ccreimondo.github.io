# Bottom Halves
pass

## Softirqs

### do_softirq()
以下情况会周期性检查本地挂起的软中断并执行do_softirq()：
- local_bh_enable()时
- irq_exit()时
- smp_apic_timer_interrupt()后
- 完成处理器间中所触发的函数
- ksoftirqd/n被唤醒

### softirq中的同步问题
softirq是由中断调用raise_softirq()而挂起的，我们可以简单粗暴的通过禁止本地中断来避免软中断
带来的并发访问。当然，我应该通过local_bh_disble()来禁止本地软中断。


## Tasklets
pass


## Work Queues
pass
