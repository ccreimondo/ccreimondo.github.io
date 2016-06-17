# Asynchronous Interrupt
我将借助内核中的周期性硬件时钟中断走一下linux异步中断的处理流程。我们默认计算机是单处理器，
且所有的计时活动都是由全局定时器产生的中断触发的。Linux内核代码版本为2.6.34.71。


## 中断原理
硬件中断来自于CPU外设，也称异步中断。x86体系结构中，外部设备和CPU之间是借助PIC传递信息，
e.g. 中断请求信号、中断号。而CPU是借助中断向量表（IDT）帮助操作系统区分不同的中断，即根据
中断号装载IDT中对应表项所指定的入口IP。操作系统则需要实现IDT中所约定的中断处理程序（ISA）。
从PIC开始都是软件可编程的。


## 时钟中断
时钟中断是linux中最基本的事件。内核借助它进行周期性地：
- 更新自系统启动以来所经过的事件;
- 更新时间和日期;
- 统计进程运行时间并适时进行调度;
- 更新资源使用统计数;
- 检查延迟函数是否需要执行。


## 源码解析
在x86_64中，内核对普通的硬件中断一般有这样的路线：common_intrrupt=>do_IRQ()
=>handle_irq()=>generic_handle_irq_desc()=>irq_desc[irq]->handle_irq()
=>handle_IRQ_event()=>irq_desc[irq]->action->handler(irq, action->dev_id)。

内核初始化IDT中的中断门，使其指向下面代码片段.

```asm
/*
 * x86/kernel/entry_64.S::ENTRY(irq_entires_interrupt)
 */

ENTRY(irq_entries_start)
	INTR_FRAME
vector=FIRST_EXTERNAL_VECTOR
.rept (NR_VECTORS-FIRST_EXTERNAL_VECTOR+6)/7
	.balign 32
  .rept	7
    .if vector < NR_VECTORS
      .if vector <> FIRST_EXTERNAL_VECTOR
	CFI_ADJUST_CFA_OFFSET -8
      .endif
1:	pushq $(~vector+0x80)	/* Note: always in signed byte range */
	CFI_ADJUST_CFA_OFFSET 8
      .if ((vector-FIRST_EXTERNAL_VECTOR)%7) <> 6
	jmp 2f
      .endif
      .previous
	.quad 1b
      .text
vector=vector+1
    .endif
  .endr
2:	jmp common_interrupt
.endr
	CFI_ENDPROC
END(irq_entries_start)
```

TODO


```c
/*
 * x86/kernel/entry_64.S::common_interrupt
 */
common_interrupt:
	XCPT_FRAME
	addq $-0x80,(%rsp)		/* Adjust vector to [-256,-1] range */
	interrupt do_IRQ
	...
```

把中断号-256的结果存在栈里，并call do_IRQ。

```c
/* 
 * x86/kernel/irq.c::do_IRQ()
 */
unsigned int __irq_entry do_IRQ(struct pt_regs *regs)
{
	struct pt_regs *old_regs = set_irq_regs(regs);

	/* high bit used in ret_from_ code  */
	unsigned vector = ~regs->orig_ax;
	unsigned irq;

	exit_idle();
	irq_enter();

	irq = __get_cpu_var(vector_irq)[vector];
```

irq_enter()会增加当前thread_info中的preempt_count中的中断计数器，以禁止内核抢占。irq
为内核从栈中提取的中断号。

```c
	if (!handle_irq(irq, regs)) {
		ack_APIC_irq();

		if (printk_ratelimit())
			pr_emerg("%s: %d.%d No irq handler for vector (irq %d)\n",
				__func__, smp_processor_id(), vector, irq);
	}

	irq_exit();

	set_irq_regs(old_regs);
	return 1;
}
```

do_IRQ()调用handle_irq()处理中断，若当前中断无对应处理函数，应答中断并打印错误。
irq_exit()会递减中断计数器并检查是否有可延迟函数正等待执行。


```c
/*
 * x86/kernel/irq_64.c::handle_irq()
 */
bool handle_irq(unsigned irq, struct pt_regs *regs)
{
	struct irq_desc *desc;

	stack_overflow_check(regs);

	desc = irq_to_desc(irq);
	if (unlikely(!desc))
		return false;

	generic_handle_irq_desc(irq, desc);
	return true;
}
```
stack_overflow_check()用于调试内核栈的使用情况。irq_to_desc()等效于return irq_desc_ptrs[irq]。
内核中的中断描述符表是一个irq_desc数组，数组的每一项描述一根中断线的信息，包括芯片中断处理
程序、底层硬件操作函数、注册的中断处理程序链表等。至此，我们获得了中断相应描述符并调用
generic_handle_irq_desc()继续处理中断。

```c
/*
 * include/linux/irq.h::generic_handle_irq_desc()
 */
static inline void generic_handle_irq_desc(unsigned int irq, struct irq_desc *desc)
{
#ifdef CONFIG_GENERIC_HARDIRQS_NO__DO_IRQ
	desc->handle_irq(irq, desc);
#else
	if (likely(desc->handle_irq))
		desc->handle_irq(irq, desc);
	else
		__do_IRQ(irq);
#endif
}
```
它直接调用desc->handle_irq继续处理中断。handle_irq是函数指针，指向kernel/irq/chip.c中
的中断事件处理函数：
- handle_simple_irq
- handle_level_irq
- handle_fasteoi_irq
- handle_edge_irq
- handle_percpu_irq

这个函数指针是由kernel/irq/chip.c中的__set_irq_handler()设置的。这种组织方式比传统的
__do_IRQ()更加清晰和灵活。以下，我们分析下handle_irq中的一类处理函数handle_simple_irq()。

```c
/*
 * kernel/irq/chip.c::handle_simple_irq
 */
void
handle_simple_irq(unsigned int irq, struct irq_desc *desc)
{
	struct irqaction *action;
	irqreturn_t action_ret;

	spin_lock(&desc->lock);

	if (unlikely(desc->status & IRQ_INPROGRESS))
		goto out_unlock;
	desc->status &= ~(IRQ_REPLAY | IRQ_WAITING);
	kstat_incr_irqs_this_cpu(irq, desc);
```

IRQ_INPROGRESS被设置意味着另一个CPU可能处理同一个中断的前一次出现，推迟本次中断到那个CPU
上去处理。否则，handle_simple_irq()清除IRQ_REPLAY和IRQ_WAITING并增加本地中断技术。
IRQ_REPLY用于产生一个自我中断。

```c
	action = desc->action;
	if (unlikely(!action || (desc->status & IRQ_DISABLED)))
		goto out_unlock;

	desc->status |= IRQ_INPROGRESS;
	spin_unlock(&desc->lock);
```

首先，函数获得当前中断描述符中的action指针。该指针指向一个irqaction链表，每一个结构体描述
一个中断处理程序。然后，函数确保当前中断的处理程序存在且当前中断线未被禁止，并设置当前中断
处于处理状态。

```c
	action_ret = handle_IRQ_event(irq, action);
	if (!noirqdebug)
		note_interrupt(irq, desc, action_ret);

	spin_lock(&desc->lock);
	desc->status &= ~IRQ_INPROGRESS;
out_unlock:
	spin_unlock(&desc->lock);
}
```

函数调用调用handle_IRQ_event(irq, action)运行相应的中断处理程序。中断处理完成后，
IRQ_INPROGRESS被清除。

```c
/*
 * kernel/irq/handle.c::handle_IRQ_event()
 */
irqreturn_t handle_IRQ_event(unsigned int irq, struct irqaction *action)
{
	irqreturn_t ret, retval = IRQ_NONE;
	unsigned int flags = 0;

	if (!(action->flags & IRQF_DISABLED))
		local_irq_enable_in_hardirq();
```

若当前中断未被设置IRQF_DISABLED，则需要通过local_irq_enable_in_hardirq()打开本地中断，
以共享当前中断线。

```c
	do {
		trace_irq_handler_entry(irq, action);
		ret = action->handler(irq, action->dev_id);
		trace_irq_handler_exit(irq, action, ret);
```

程序编译运行action链表中的所有处理函数。

```c
		switch (ret) {
		case IRQ_WAKE_THREAD:
			ret = IRQ_HANDLED;
```

case IRQ_WAKE_THREAD用于捕获返回值为WAKE_THREAD的驱动程序。设置IRQ_HANDLED指明该中断
处理程序已运行，防止可疑的检查不再触发。


```
			if (unlikely(!action->thread_fn)) {
				warn_no_thread(irq, action);
				break;
			}

			if (likely(!test_bit(IRQTF_DIED,
					     &action->thread_flags))) {
				set_bit(IRQTF_RUNTHREAD, &action->thread_flags);
				wake_up_process(action->thread);
			}
```

在确保中断线程有相应的线程函数后，handle_IRQ_event()通过wake_up_process()唤醒线程。若
线程奔溃且被杀死，我们仅仅假装已经处理了该中断。

```c
			/* Fall through to add to randomness */
		case IRQ_HANDLED:
			flags |= action->flags;
			break;

		default:
			break;
		}

		retval |= ret;
		action = action->next;
	} while (action);

	add_interrupt_randomness(irq, flags);
	local_irq_disable();

	return retval;
}
```

add_interrupt_randommness()使用中断间隔时间为随机数产生熵。local_irq_disable()再次禁
止中断（do_IRQ(）期望中断一直时禁止的）。

```c
/*
 * x86/kernel/time.c::setup_default_timer_irq()
 */
static struct irqaction irq0  = {
	.handler = timer_interrupt,
	.flags = IRQF_DISABLED | IRQF_NOBALANCING | IRQF_IRQPOLL | IRQF_TIMER,
	.name = "timer"
};

void __init setup_default_timer_irq(void)
{
	setup_irq(0, &irq0);
}
```

以上是内核初始化时钟中断的函数。setup_irq会将irq_action irq0添加到0号中断线描述符中的
action链表中。其中，我们只要实现中断处理函数和设置flags。


## References:
- 深入理解LINUX内核. 第3版.
- 内核设计与实现. 第3版.
- http://home.ustc.edu.cn/~boj/courses/linux_kernel/2_int.html