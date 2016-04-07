# Linked List in Linux Kernel

## `list_head`

```c
/* linux/list.h */
struct list_head {
	struct list_head *next, *prev;
};
```


## `container_of` and `list_entry`

```c
/* linux/stddef.h */
#undef NULL
#if defined(__cplusplus)
#define NULL 0
#else
#define NULL ((void *)0)

#endif
#undef offsetof
#ifdef __compiler_offsetof
#define offsetof(TYPE,MEMBER) __compiler_offsetof(TYPE,MEMBER)
#else
#define offsetof(TYPE, MEMBER) ((size_t) &((TYPE *)0)->MEMBER)

/* linux/kernel.h */
/**
 * container_of - cast a member of a structure out to the containing structure
 * @ptr:	the pointer to the member.
 * @type:	the type of the container struct this is embedded in.
 * @member:	the name of the member within the struct.
 *
 */
#define container_of(ptr, type, member) ({			\
	const typeof( ((type *)0)->member ) *__mptr = (ptr);	\
	(type *)( (char *)__mptr - offsetof(type,member) );})

/* linux/list.h */
/**
 * list_entry - get the struct for this entry
 * @ptr:	the &struct list_head pointer.
 * @type:	the type of the struct this is embedded in.
 * @member:	the name of the list_struct within the struct.
 */
#define list_entry(ptr, type, member) \
	container_of(ptr, type, member)
```

- `offsetof(TYPE, MEMBER)`中`&((TYPE *)0)->MEMBER`是｀((TYPE *)0)->MEMBER`在`(TYPE *)0)`中的地址。为什么`((size_t) &((TYPE *)0)->MEMBER)`直接得出`((TYPE *)0)->MEMBER`在`(TYPE *)0`中的偏移量？`(TYPE *)0`的值为0（一个为NULL的指针无条件返回0），所以。。。
- 0在`(type *)0`中表示什么?见上代码中的NULL的定义，0即NULL（好像逻辑有点不对，明明`#define NULL 0`），一个值为0的指针变量（可以程序`printf("%d\n", (int)NULL)`验证一下）。`(type *)0`即`(type *)((void *)0)`。不这样（即没有一个合法的(type *)变量），就没法访问MEMBER，更没法`typeof()`了。
- `typeof()`如何工作？`sizeof()`呢？
- `offsetof`中`&((TYPE) *)0)->MEMBER`为什么需要转为`size_t`?`(char *)__mptr`为什么需要转换为`char *`？
- 为什么不能`typeof(ptr) __mptr = ptr`，而要`typeof(((type *)0)->member) *__mptr = (ptr)`?我猜，指针只是单纯保存某变量的内存地址，无法体现变量的具体类型。
- 为什么不直接`(ptr) - offsetof(type, member)`？`const typeof( ((type *)0)->member ) *__mptr = (ptr)`可以让编译器在编译时检查（ptr）是否符合指定指针类型(即是否是typeof((type *)0)->member))。这里，我们会把(ptr)转化为(char *)，如果不做类型检查，则无论ptr是什么都会编译通过。

## `list_for_each` and `list_for_each_entry`

```c
/* linux/list.h */
/**
 * list_for_each	-	iterate over a list
 * @pos:	the &struct list_head to use as a loop cursor.
 * @head:	the head for your list.
 */
#define list_for_each(pos, head) \
	for (pos = (head)->next; prefetch(pos->next), pos != (head); \
        	pos = pos->next)

/**
 * list_for_each_entry	-	iterate over list of given type
 * @pos:	the type * to use as a loop cursor.
 * @head:	the head for your list.
 * @member:	the name of the list_struct within the struct.
 */
#define list_for_each_entry(pos, head, member)				\
	for (pos = list_entry((head)->next, typeof(*pos), member);	\
	     prefetch(pos->member.next), &pos->member != (head); 	\
	     pos = list_entry(pos->member.next, typeof(*pos), member))
```

- `prefetch(x)`?

```c
/* linux/prefetch.h */
/*
 * prefetch(x) attempts to pre-emptively get the memory pointed to
 * by address "x" into the CPU L1 cache. 
 * prefetch(x) should not cause any kind of exception, prefetch(0) is
 * specifically ok.
 * prefetch() should be defined by the architecture, if not, the 
 * #define below provides a no-op define.	
 * 
 * There are 3 prefetch() macros:
 * 
 * prefetch(x)  	- prefetches the cacheline at "x" for read
 * prefetchw(x)	- prefetches the cacheline at "x" for write
 * spin_lock_prefetch(x) - prefetches the spinlock *x for taking
 */
```

## `hlist_head` & `hlist_node`

```c
struct hlist_head {
	struct hlist_node *first;
};

struct hlist_node {
	struct hlist_node *next, **pprev;
};
```

这个相比于前一种链表的实现，不同点有：
- 多维护了一个`hlist_head`，且该结构体中只有一个指针。
- `**pprev`指向前一个`hlist_node`的`&next`。它为什么不直接指向`hlist_node`？因为链表中，有一个特别的结构`hlist_head`，`struct hlist_node *prev`拿它没办法，但每个结构题中都一个`struct hlist_node *`，所以采用`struct hlist_node **pprev`。

hlist专为hash table设计（hlist中的h是不是就是hash？）。只有一个成员的`hlist_head`相比有两个成员的`list_head`，在hash table中占用更小空间的表项。这样，固定大小的hash table可以多一倍的表项。为什么不在slot里面存一个指向链表某个node的指针呢？其实hlist_head本质上就是封装了一个指向链表的指针。pid_hash定义在kernel/pid.c: `static struct hlist_head *pid_hash;`。


## References
- [Why this 0 in ((type*)0)->member in C?](http://stackoverflow.com/questions/13723422/why-this-0-in-type0-member-in-c)
