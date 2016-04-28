# Process Scheduling

## Task Traits
I/O bound or processor bound.


## Completely Fair Scheduler, CFS
>CFS is based on a simple concept: Model process scheduling as if the system
 had an ideal, perfectly multitasking processor. In such a system, each process
 would receive 1/n of the processor’s time, where n is the number of runnable
 processes, and we’d schedule them for infinitely small durations, so that in
 any measurable period we’d have run all n processes for the same amount of
 time.


## Scheduler Classes
pass


## Caller of schedule()
schedule()可以由几个内核控制路径调用，可以采取直接调用或延迟调用的方式。直接
调用发生在进程因不能获取必需的资源而立刻被阻塞或者就是运行完了而让出CPU。延迟
调用即通过设置TIF_NEED_RESCHED标志，然后以下情况会检查该标志并调用schedule():
- 异常和中断返回之前
- 内核代码再一次具有可抢占性的时候（preempt_count == 0）

两者有一定的联系，异常和中断返回之前先检查preempt_count再检查TIF_NEED_RESCHED。
只有preempt_count == 0 && TIF_NEED_RESCHED == 1时才会调用schedule()。内核代
码再一次具有可抢占性的时候指preempt_enable()之类的函数：使preemt_count为0，并在
TIF_NEED_RESCHED == 1时调用preempt_schedule()。preempt_schedule()则是设置
PREEMPT_ACTIVE后再调用schedule()。

以上原则告诉我们：只有当内核正在执行异常处理程序（尤其是系统调用），而且内核抢
占没有被显示禁用时，才可能抢占内核。此外，本地CPU必须打开本地中断，否则无法完成
内核抢占（这里的抢占内核就是指发生调度）。

备注：preempt_count由四个字段组成，0～7为抢占计数器，8～15为软中断计数器，16～
27为硬中断计数器，28为PREEMPT_ACTIVE标志。它们分别会在以下情况被修改：
- 显示禁用、解除本地CPU内核抢占会修改第一个计数器
 - preempt_enable() or preempt_enable_no_resched() or preempt_disable()...
- 禁用、解除延迟函数会修改第二个计数器
 - local_bh_enable() or local_bh_disbale()
- 进入和退出硬中断会修改第三个计数器
 - irq_enter() or irq_exit
- preempt_schedule()会修改第四个PREEMPT_ACTIVE标志


## `schedule()`
`schedule()`实现程序调度。它的任务是从运行队列的链表中找到一个进程，并随后将
CPU分配给这个进程。其中，prev指向被替换的进程描述符，next指向被选中的进程。

```c
asmlinkage void __sched schedule(void)
{
        struct task_struct *prev, *next;
        unsigned long *switch_count;
        struct rq *rq;
        int cpu;

need_resched:
        preempt_disable();
        cpu = smp_processor_id();
        rq = cpu_rq(cpu);
        rcu_sched_qs(cpu);
        prev = rq->curr;
        switch_count = &prev->nivcsw;
```

函数在一开始先禁用内核抢占，并初始化一些局部变量。禁止抢占是为了避免内核抢占带
来的并发问题。prev指向当前本地进程的描述符。

```c
        release_kernel_lock(prev);
```

大内核锁（BKL）是一个全局内核锁，用于保护内核数据结构。它结合每个进程描述符中的
lock_depth使用。lock_depth为-1表示当前进程持有BKL。schedule()会调用
release_kernel_lock()以释放BKL，当然只有lock_depth>=0时才会用真正释放BKL，否则
绝不能释放。对于抢占而调用schedule的情况，lock_depth在preempt_schedule()中被置
为-1以避免抢占的进程失去BKL。

```c
        spin_lock_irq(&rq->lock);
        update_rq_clock(rq);
        clear_tsk_need_resched(prev);

```

update_rq_clock()用于更新rq的clock。像CFS中，update_curr就会利用rq->clock进行时
间记账。因为后面代码会对rq做一些数据修改，所以需要获取rq中的spin_lock，且这里
用到的sping_lock_irq()既禁止本地中断又获取spin_lock以分别解决来自中断和SMP的并
发访问。

```c
        if (prev->state && !(preempt_count() & PREEMPT_ACTIVE)) {
                if (unlikely(signal_pending_state(prev->state, prev)))
                        prev->state = TASK_RUNNING;
                else
                        deactivate_task(rq, prev, 1);
                switch_count = &prev->nvcsw;
        }
```

判断是否移除非运行状态的prev。PREEMPT_ACTIVE被设置表示schedule是由于内核抢占而
被调用的。在这里，如果未设置PREEMPT_ACTIVE且prev不存在未处理的信号，则将prev从
rq里移除。除此之外，prev仍留在rq中并有机会运行。考虑这样一种情况，某进程运行过
程中改变了自己的state，在它还没有将自己加入到wait_queue时被抢占了，然后以上代
码便负责将它移除rq。

```c
        pre_schedule(rq, prev);

        if (unlikely(!rq->nr_running))
                idle_balance(cpu, rq);
```

如果本地rq没有运行进程可选，就调用idle_balance()尝试从其它CPU的rq里拖点tasks到
本地rq中。

```c
        put_prev_task(rq, prev);
        next = pick_next_task(rq);

        if (likely(prev != next)) {
                sched_info_switch(prev, next);
                perf_event_task_sched_out(prev, next, cpu);

                rq->nr_switches++;
                rq->curr = next;
                ++*switch_count;

                context_switch(rq, prev, next); /* unlocks the rq */
                /*
                 * the context switch might have flipped the stack from under
                 * us, hence refresh the local variables.
                 */
                cpu = smp_processor_id();
                rq = cpu_rq(cpu);
        } else
                spin_unlock_irq(&rq->lock);
```

pick_next_task选择下一个即将运行的进程且next指向该进程描述符。如果prev和next不
是同一个进程，那么先通过sched_info_switch()更新两个进程描述符的相关字段，并且
更新可运行队列的相关字段。然后就是context_switch()进行prev和next两个进程的上下
文切换。

```c
        post_schedule(rq);

        if (unlikely(reacquire_kernel_lock(current) < 0))
                goto need_resched_nonpreemptible;

```

尝试重为当前进程获取BKL，不成功则表示BKL已被持有，则再次进行调度。

```c
        preempt_enable_no_resched();
        if (need_resched())
                goto need_resched;
}
```

preempt_enable_no_resched()启用内核抢占。如果需要resched，则再次进行调度。


##context_switch()
context_switch()函数建立next的地址空间并完成进程切换。

```c
/*
 * context_switch - switch to the new MM and the new
 * thread's register state.
 */
static inline void
context_switch(struct rq *rq, struct task_struct *prev,
               struct task_struct *next)
{
        struct mm_struct *mm, *oldmm;

        prepare_task_switch(rq, prev, next);
        trace_sched_switch(rq, prev, next);
        mm = next->mm;
        oldmm = prev->active_mm;

```

初始化一些局部变量，主要为prev和next的地址空间(mm_struct)。

```c
        /*
         * For paravirt, this is coupled with an exit in switch_to to
         * combine the page table reload and the switch backend into
         * one hypercall.
         */
        arch_start_context_switch(prev);

        if (unlikely(!mm)) {
                next->active_mm = oldmm;
                atomic_inc(&oldmm->mm_count);
                enter_lazy_tlb(oldmm, next);
        } else
                switch_mm(oldmm, mm, next);
```

这里考虑到next可能是一个内核线程，而它并没有自己的地址空间。如果next是一个内核
线程，就设置next的地址空间指向prev->active_mm指向的地址空间，并增加该mm_struct
的引用计数。否则，调用switch_mm()用next的地址空间替换prev的地址空间。


```c
        if (unlikely(!prev->mm)) {
                prev->active_mm = NULL;
                rq->prev_mm = oldmm;
        }
```

如果prev是内核线程，就保存prev->active_mm到rq->prev_mm中，然后恢复
prev->prev_mm为NULL。

```c
        /*
         * Since the runqueue lock will be released by the next
         * task (which is an invalid locking op but in the case
         * of the scheduler it's an obvious special-case), so we
         * do an early lockdep release here:
         */
#ifndef __ARCH_WANT_UNLOCKED_CTXSW
        spin_release(&rq->lock.dep_map, 1, _THIS_IP_);
#endif

        /* Here we just switch the register state and the stack. */
        switch_to(prev, next, prev);
```

通过witch_to()完成栈和寄存器的切换。此函数中，当前CPU会执行另一个进程。

```c
        barrier();
        /*
         * this_rq must be evaluated again because prev may have moved
         * CPUs since it called schedule(), thus the 'rq' on its stack
         * frame will be invalid.
         */
        finish_task_switch(this_rq(), prev);
}
```

这里，当程序重新被调度运行。barrier()产生一个代码优化屏障后执行
finish_task_switch()主要在prev是内核线程时，恢复其active_mm，调用mmdrop减少其
借用的地址空间的引用计数。如果，prev是否是一个正在从系统中被删除的僵尸任务，如
果是就调用put_task_struct()以释放进程描述符引用计数器，并撤销所有其余对该进程
的引用。

## References:
- 深入理解LINUX内核. 第3版.
- Linux内核设计与实现. 第3版.
- [基于CFS算法的schdule()源码分析](http://edsionte.com/techblog/archives/3819)
