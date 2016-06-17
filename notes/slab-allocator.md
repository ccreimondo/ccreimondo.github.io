# Slab Allocator
内存分配是内核内存管理中的一个重要部分，而动态内存的分配由分配器完成。c库中有malloc，而linux内核中有page allocator、slab allocator、kmalloc和vmalloc。其中，slab allocator[1][2]用于分配那些频繁使用的内核数据结构，e.g. task_struct、mm_struct、dentry。


## Kernel Allocator Hirerachy
Linux内核中的内存分配器由下往上，有：
- page allocator: 内核中最基本的分配器，分配以2^order个连续页框组成的内存块；
- slab allocator: 用于分配内核中频繁使用的数据结构对象；
- kmalloc: 类似用户空间的malloc，分配以字节为单位的内存块。
Kmalloc构建于slab allocator之上，而slab allocator构建于page allocator之上。我们有理由推断slab分配器主要请求DMA、NORMAL区域里的页框。page_address()用于返回frame所对应的线性地址，它区分HIGHMEM和非HIGHMEM区。对于HIGHMEM的frame，page_address返回NULL，此时，我们需要进行kmap操作。而slab分配器的页框请求接口kmem_getpages()没有kmap之类的操作。由此推断，slab分配器管理的内存落在DMA或者NORMAL区。


## Slab Allocator Implementation

### Data Structure
See 1st slide.
- kmem_cache:
- array_cache:
- kmem_list3:
- slab:
- typedef unsigned int kmem_bufctl_t:


## Slub Allocator Implementation
自linux内核2.6.23版本开始，slub allocator替代slab allocator成为默认分配器[3]。为了保持兼容性，slub allocator提供了和slab allocator一样的API。

### Data Structure
See 2nd slide.
- kmem_cache:
- kmem_cache_cpu:
- kmem_cache_node:

### Slub Overloaded Variables in Struct Page
See 2nd slide.

```c
/* linux-2.6.34.70/include/mm_types.h */
struct {
	u16 inuse;
	u16 objects;
};
struct kmem_cache *slab;	/* SLUB: pointer to kmem_cache */
void   *freelist;			/* SLUB: freelist req. slab lock */
struct list_head  lru;		/* SLUB中用于维护SLAB链表 */
```


## Difference between the Slab and Slub
See 2nd slide。这封来自Christoph Lameter的邮件[4]列举了slub的新特点和slab的缺点。[5]中的文章简单介绍了slub的新特点。


## Probe Slub Allocator
探究想法来自这篇文章[6]。探究问题包括：
- slub分配器持有的页框类型和相应的页框总个数；
- slub分配器中不同类型页框的使用者和它们特征；
- slub持有页框在物理内存的分布情况，我们设计扫描页帧描述符数组mem_map来统计属于slub分配器的页帧分布情况，但未完成。考虑到页框由page allocator管理，页框的分布对slub分配器来说是不可见的，我们不确定该探究是否具有意义。

### Related CONFIG_FLAGS
- CONFIG_SLUB_STATS, default no
- CONFIG_SLUB_DEBUG, default yes
- CONFIG_SLUB_DEBUG_ON, default no
- CONFIG_KMEMTRACE, ???
- CONFIG_NUMA, default yes
- CONFIG_SMP, default yes or it depends
- CONFIG_ZONE_DMA, default yes
- CONFIG_MEMORY_HOTPLUG, default yes
- CONFIG_SLABINFO, default yes

### Kernel Built-in Tools
- perf_events
- procfs
  - /proc/buddyinfo
  - /proc/slabinfo
  - /proc/meminfo
  - /proc/pagetypeinfo: Unmovable, Movabl, Reclaimable, HighAtomic, CMA, Isolate
  - /proc/vmstat 

### Available Data Source
- mem_map
- /proc/slabinfo

### Data Analysis
See 2nd slide. Source code and raw data we used are available on https://github.com/ccreimondo/probeslab.


## References
- [1] Jeff Bonwick, Sun Microsystems. The Slab Allocator: An Object-Caching Kernel Memory Allocator.
- [2] Jeff Bonwick, Sun Microsystems & Jonathan Adams, California Institute of Technology. Magazines and Vmem: Extending the Slab Allocator to Many CPUs and Arbitrary Resources.
- [3] Make SLUB the default allocator. (2007, July 17). http://git.kernel.org/cgit/linux/kernel/git/torvalds/linux.git/commit/?id=a0acd820807680d2ccc4ef3448387fcdbf152c73.
- [4] SLUB: The unqueued slab allocator V6. (2007, Mar 31). http://lwn.net/Articles/229096/.
- [5] The SLUB allocator. (2007, April 11). http://lwn.net/Articles/229984/.
- [6] Controlling Physical Memory Fragmentation in Mobile Systems.