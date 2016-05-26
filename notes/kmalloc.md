# kmalloc
kmalloc是linux内核中类似glibc中malloc的动态内存分配器。内核借助kmalloc分配以字节为单位
的内存。以下讨论基于slab（非slub）的kmalloc。


## 原理分析
Linux内核中，页帧分配器（page allocator）借助伙伴系统（buddy system）管理物理页帧。
Slab分配器构建于页帧分配器之上，用于分配内核频繁创建和释放的数据结构对象。Kmalloc又构建于
slab分配器之上，用于分配任意以字节为单位的内存。Kmalloc在slab分配器中创建了几组通用高速
缓存。这些高速缓存中的对象具有几何分布的大小，范围如下（单位为byte）：
```c
/* include/kmalloc_sizes.h */
#if (PAGE_SIZE == 4096)
	CACHE(32)
#endif
	CACHE(64)
#if L1_CACHE_BYTES < 64
	CACHE(96)
#endif
	CACHE(128)
#if L1_CACHE_BYTES < 128
	CACHE(192)
#endif
	CACHE(256)
	CACHE(512)
	CACHE(1024)
	CACHE(2048)
	CACHE(4096)
	CACHE(8192)
	CACHE(16384)
	CACHE(32768)
	CACHE(65536)
	CACHE(131072)
...
```
对于每一次分配请求，kmalloc在通用高速缓存里寻找能容下size的最小缓存并从中返回一个通用对象。


## 源码分析

```c
static __always_inline void *kmalloc(size_t size, gfp_t flags)
{
	struct kmem_cache *cachep;
	void *ret;
```

kmalloc有两个常用接口，void *kmalloc(size_t size, gfp_t flags)和
void kfree(const void *objp)，分别用于请求和释放对象。其中，内核内存分配需要指定
GFP (Get Free Page) flags。该flags被页框分配器用于区分页框所在区域。Kmalloc返回对象的
指针。

```c
	if (__builtin_constant_p(size)) {
```

__builtin_constant_p是GCC内建函数，用于判断size是否为编译时常数。该条件分支下的宏代码会
被编译器优化，即直接算出i的值。__always_inline前缀强制限定该函数是一个inline函数，所以以
上优化是有有意义的。


```
		int i = 0;

		if (!size)
			return ZERO_SIZE_PTR;

#define CACHE(x) \
		if (size <= x) \
			goto found; \
		else \
			i++;
#include <linux/kmalloc_sizes.h>
#undef CACHE
		return NULL;
```

为size找适合的通用缓存，并返回该缓存的索引i。


```c
found:
#ifdef CONFIG_ZONE_DMA
		if (flags & GFP_DMA)
			cachep = malloc_sizes[i].cs_dmacachep;
		else
#endif
			cachep = malloc_sizes[i].cs_cachep;

		ret = kmem_cache_alloc_notrace(cachep, flags);

		trace_kmalloc(_THIS_IP_, ret,
			      size, slab_buffer_size(cachep), flags);

		return ret;
	}
```

通常情况下，malloc创建了13个通用caches并保存在malloc_size数组里面。数组项类型为
struct cache_sizes（后面会说）。若flags里面含有GFP_DMA标志，则cachep指向dmacachep。
kmem_cache_alloc_notrace是slab分配器提供的接口，根据给定cachep返回一个空闲对象的指针。


```c
	return __kmalloc(size, flags);
}
```

若__builtin_constant_p不成立，则kmalloc调用__kmalloc。而__kmalloc则直接调用__do_kmalloc。


```c
static __always_inline void *__do_kmalloc(size_t size, gfp_t flags,
					  void *caller)
{
	struct kmem_cache *cachep;
	void *ret;

	cachep = __find_general_cachep(size, flags);
```

调用__find_general_cachep返回适合size的通用缓存（后面会说该函数）。

```c
	if (unlikely(ZERO_OR_NULL_PTR(cachep)))
		return cachep;
	ret = __cache_alloc(cachep, flags, caller);

	trace_kmalloc((unsigned long) caller, ret,
		      size, cachep->buffer_size, flags);

	return ret;
}
```

获得cachep后，__do_kmalloc直接调用__cache_alloc来分配一个空闲的object并返回。

```c
static inline struct kmem_cache *__find_general_cachep(size_t size,
							gfp_t gfpflags)
{
	struct cache_sizes *csizep = malloc_sizes;

#if DEBUG
	/* This happens if someone tries to call
	 * kmem_cache_create(), or __kmalloc(), before
	 * the generic caches are initialized.
	 */
	BUG_ON(malloc_sizes[INDEX_AC].cs_cachep == NULL);
#endif
	if (!size)
		return ZERO_SIZE_PTR;

	while (size > csizep->cs_size)
		csizep++;
```

csizep指向malloc_size数组。while循环遍历csizep寻找适合size的通用缓存。最后，csizep指向
该数组项。


```c
	/*
	 * Really subtle: The last entry with cs->cs_size==ULONG_MAX
	 * has cs_{dma,}cachep==NULL. Thus no special case
	 * for large kmalloc calls required.
	 */
#ifdef CONFIG_ZONE_DMA
	if (unlikely(gfpflags & GFP_DMA))
		return csizep->cs_dmacachep;
#endif
	return csizep->cs_cachep;
}
```

根据是否有GFP_DMA返回相应的cachep。


```c
void kfree(const void *objp)
{
	struct kmem_cache *c;
	unsigned long flags;

	trace_kfree(_RET_IP_, objp);

	if (unlikely(ZERO_OR_NULL_PTR(objp)))
		return;
	local_irq_save(flags);
	kfree_debugcheck(objp);
	c = virt_to_cache(objp);
	debug_check_no_locks_freed(objp, obj_size(c));
	debug_check_no_obj_freed(objp, obj_size(c));
	__cache_free(c, (void *)objp);
	local_irq_restore(flags);
}
EXPORT_SYMBOL(kfree);
```

kfree用于释放objp指向的对象。virt_to_cache（后面细说）函数根据objp存的地址返回当前高速
缓存描述符。kfree调用__cache_free释放objp。kfree在释放一个对象之前做了一些检查，我们需
要禁止本地中断保证这段代码的原子性，即__cache_free时，检查依然是有效的。


```c
/* mm/slab.c */
static inline struct kmem_cache *virt_to_cache(const void *obj)
{
	struct page *page = virt_to_head_page(obj);
	return page_get_cache(page);
}

static inline struct kmem_cache *page_get_cache(struct page *page)
{
	page = compound_head(page);
	BUG_ON(!PageSlab(page));
	return (struct kmem_cache *)page->lru.next;
}
```

Commpound page是连续页框联合的一种形式，可形成较大的页。一个commpound page中每个page描
述符中的first_page指向第一个页框的描述符。compound_head函数可以帮助我们判断当前页是否属于
commpound page并返回head page的描述符。通过读取页框描述符的lru.next字段，就可以确定出
对应的高速缓存描述符地址。


```c
/* include/linux/mm.h */
static inline struct page *virt_to_head_page(const void *x)
{
	struct page *page = virt_to_page(x);
	return compound_head(page);
}
```

virt_to_page(addr)宏产生线性地址addr对应的页描述符。结合上文，virt_to_page在这里返回
obj所在页的描述符地址。

```c
/* arch/x86/include/asm/page.h */
#define virt_to_page(kaddr)	pfn_to_page(__pa(kaddr) >> PAGE_SHIFT)
```

pfn_to_page(pfn)宏产生与页框号pfn对应的页描述符地址。__pa(kaddr)宏产生内核虚拟地址对应
的物理地址。在x86_32上，它只要将kaddr减去0xc0000000(PAGE_OFFSET)。>> PAGE_SHIFT除去
页内offset所用的bit，留下页帧号。

```c
/* Size description struct for general caches. */
struct cache_sizes {
	size_t		 	cs_size;
	struct kmem_cache	*cs_cachep;
#ifdef CONFIG_ZONE_DMA
	struct kmem_cache	*cs_dmacachep;
#endif
};
extern struct cache_sizes malloc_sizes[];
```

其中，每一个通用cache区分DMA和非DMA。Linux将一个内存节点分为三个区，DMA、NORMAL
和HIGHMEM。DMA硬件可以直接访问DMA区。