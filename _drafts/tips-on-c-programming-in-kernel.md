# Tips on C Programming in Linux Kernel


## Declaring and Defining

### `extern`
用于声明，其后的变量或函数可能在当前文件或其它文件中定义。形如`int i = 10;`为定义且声明且初始化。

### `static`

### `volatile`
关于`volatile`, Documentation/volatile-considered-harmful.txt 里面有这样的描述:
>C程序员通常认为volatile表示某个变量可以在当前执行的线程之外被改变；因此，在内核中用到共享数据结构时，常常会有C程序员喜欢使用volatile这类变量。换句话说，他们经常会把volatile类型看成某种简易的原子变量，当然它们不是。。。

### `asm`
- asm [volatile](“code template”:outputs:inputs:clobbers)
- volatile指明编译器不优化这些汇编指令

```c
/* e.g. */
asm (“foo %1, %0”
	: “=r” (output)
	: “r” (input1), “0” (input2));
```


##`sizeof`
- `sizeof(struct struct_type)`:
- `sizeof(pointer)`:


## Bitwise Operatiors and Operations

- &, | (bitwise inclusive OR), ^ (bitwise exclusive OR), << (left shift), >>, ~ (one's complement (unary)).
- Precedence: ~, <<, >>, &, ^, |, &=, ^=, |=, <<=, >>= (left to right).
- The bitwise AND operator & is often used to mask off some set of bits. e.g n &= 0177 (sets to zero all but the low-order 7 bits of n); x &= ~077 (sets the last six bits of x to zero).
- The bitwise OR operator | is used to turn bits on. e.g. x |= SET_ON (sets to one in x the bits that are set to one in SET_ON).

## Q&A
Q1. In the following snippet:

```c
struct timespec {
	__kernel_time_t	tv_sec;			/* seconds */
	long		tv_nsec;		/* nanoseconds */
};

struct timeval {
	__kernel_time_t		tv_sec;		/* seconds */
	__kernel_suseconds_t	tv_usec;	/* microseconds */
};
```

What's `__kernel_time_t` and where's it defined?

A: TODO (@Zhiqiang He):

Q2. In the following snippet:

```c
#define seqlock_init(x)					\
	do {						\
		(x)->sequence = 0;			\
		spin_lock_init(&(x)->lock);		\
	} while (0)
```

Why is `do { ... } while(0)`?

A: See [Do-While and if-else statements in C/C++ macros](http://stackoverflow.com/questions/154136/do-while-and-if-else-statements-in-c-c-macros).


## Refernces
- Brian W. Kernighan, Dennis M. Ritchie. The C Programming Language, 2rd Edition.