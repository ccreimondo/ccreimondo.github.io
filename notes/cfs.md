# Completely Fair Scheduler


## Task Traits
I/O bound or CPU bound.


## Structures
- struct rq: per-CPU variable, e.g. nr_running, cpu_load, (cfs_rq)cfs, (rt_rq)rt
- struct cfs_rq: e.g. (rb_root)tasks_timeline
- struct sched_entity: e.g. (rb_node)run_node, vruntime
- struct sched_class: 


## Load
TODO


## Time Accounting

### Initialize

```c
/* kernel/sched.c */
task cfs_rq {
	struct load_weight load;
	unsigned long nr_running;

	u64 exec_clock;
	u64 min_vruntime;
	...
}
```

cfs_rq中的min_vruntime会在每次__update_curr时调用update_min_vruntime(cfs_rq)更新。

```c
/* kernel/sched_fair.c */
static void update_min_vruntime(struct cfs_rq *cfs_rq)
{
	u64 vruntime = cfs_rq->min_vruntime;

	/* 如果有运行进程，记录下它的vruntime */
	if (cfs_rq->curr)
		vruntime = cfs_rq->curr->vruntime;
	/* 找出当前cfs_rq中最小的vruntime */
	if (cfs_rq->rb_leftmost) {
		struct sched_entity *se = rb_entry(cfs_rq->rb_leftmost,
						   struct sched_entity,
						   run_node);

		if (!cfs_rq->curr)
			vruntime = se->vruntime;
		else
			vruntime = min_vruntime(vruntime, se->vruntime);
	}

	/* 保证min_vruntime的单调递增性 */
	cfs_rq->min_vruntime = max_vruntime(cfs_rq->min_vruntime, vruntime);
}
```

```c
/* kernel/sched_fair.c */
/*
 * called on fork with the child task as argument from the parent's context
 *  - child not yet on the tasklist
 *  - preemption disabled
 */
static void task_fork_fair(struct task_struct *p)
{
	struct cfs_rq *cfs_rq = task_cfs_rq(current);
	struct sched_entity *se = &p->se, *curr = cfs_rq->curr;
	int this_cpu = smp_processor_id();
	struct rq *rq = this_rq();
	unsigned long flags;

	/* 获取rq的自旋锁并关中断 */
	spin_lock_irqsave(&rq->lock, flags);

	/*
	 * 1. rq->clock = sched_clock_cpu(cpu_of(rq));
	 * 2. rq->clock_task = rq->clock - irq_time
	 */
	update_rq_clock(rq);

	if (unlikely(task_cpu(p) != this_cpu)) {
		rcu_read_lock();
		/* 移动p到this_cpu的cfs_rq */
		__set_task_cpu(p, this_cpu);
		rcu_read_unlock();
	}

	/* 更新curr（即父进程）的执行时间 */
	update_curr(cfs_rq);

	if (curr)
		/* 初始化新进程的vruntime为父进程的vruntime */
		se->vruntime = curr->vruntime;
	/* 
	 * 对于新创建的进程，该函数等效于:
	 * max(se->vruntime, cfs_rq->min_vruntime + sched_vslice_add(cfs_rq, se))
	 * sched_vslice_add: 将新进程的权重加到队列中去计算增大后调度周期,再将其增加新进程
	 * 的vruntime,保证其在当前延迟周期结束后才能运行
	 * 对于刚唤醒的进程，place_entity补偿该进程的vruntime
	 */
	place_entity(cfs_rq, se, 1);

	/* 
	 * 如果配置子进程先运行，且父进程的vruntime小于子进程的vruntime，则调换
	 * 父子进程的vruntime
	 */
	if (sysctl_sched_child_runs_first && curr && entity_before(curr, se)) {
		/*
		 * Upon rescheduling, sched_class::put_prev_task() will place
		 * 'current' within the tree based on its new key value.
		 */
		swap(curr->vruntime, se->vruntime);
		/* 设置TIF_NEED_RESCHED标志 */
		resched_task(rq->curr);
	}

	/* 在入队前先减掉当前队列的min_vruntime保证公平性 */
	se->vruntime -= cfs_rq->min_vruntime;

	spin_unlock_irqrestore(&rq->lock, flags);
}
```


### Update

```c
/* kernel/sched.c */
struct rq {
	...
	unsigned long nr_running;
	#define CPU_LOAD_IDX_MAX 5
	unsigned long cpu_load[CPU_LOAD_IDX_MAX];
	...
	/* capture load from *all* tasks on this cpu: */
	struct load_weight load;
	unsigned long nr_load_updates;
	u64 nr_switches;

	struct cfs_rq cfs;
	struct rt_rq rt;
	...
	u64 clock;
	u64 clock_task;
	...
}
```

```c
/* linux/sched.h */
struct sched_entity {
	struct load_weight	load;		/* for load-balancing */
	...
	/* now = rq_of(cfs_rq)->clock_task && delta = now - exec_start */
	u64	exec_start;
	/* sum_exec_runtime += delta */
	u64	sum_exec_runtime;
	/* vruntime += calc_delta_fair(delta, curr) */
	u64	vruntime;
	u64	prev_sum_exec_runtime;
	...
}

```

```c
/* kernel/sched_fair.c */
/* 
 * delta /= w
 */
static inline unsigned long
calc_delta_fair(unsigned long delta, struct sched_entity *se)
{
	if (unlikely(se->load.weight != NICE_0_LOAD))
		delta = calc_delta_mine(delta, NICE_0_LOAD, &se->load);

	return delta;
}

/* kernel/sched.c */
/*
 * delta *= weight / lw
 */
static unsigned long
calc_delta_mine(unsigned long delta_exec, unsigned long weight,
		struct load_weight *lw)
{
	u64 tmp;

	if (!lw->inv_weight) {
		if (BITS_PER_LONG > 32 && unlikely(lw->weight >= WMULT_CONST))
			lw->inv_weight = 1;
		else
			lw->inv_weight = 1 + (WMULT_CONST-lw->weight/2)
				/ (lw->weight+1);
	}

	tmp = (u64)delta_exec * weight;
	/*
	 * Check whether we'd overflow the 64-bit multiplication:
	 */
	if (unlikely(tmp > WMULT_CONST))
		tmp = SRR(SRR(tmp, WMULT_SHIFT/2) * lw->inv_weight,
			WMULT_SHIFT/2);
	else
		tmp = SRR(tmp * lw->inv_weight, WMULT_SHIFT);

	return (unsigned long)min(tmp, (u64)(unsigned long)LONG_MAX);
}
```