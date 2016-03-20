# Tips on C Programming in Linux Kernel


## Declaring and Defining Varibles 

### `extern`

### `static`


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
#endif

struct timeval {
	__kernel_time_t		tv_sec;		/* seconds */
	__kernel_suseconds_t	tv_usec;	/* microseconds */
};
```
What's `__kernel_time_t` and where's it defined?

A: TODO (@Zhiqiang He):


## Refernces
- Brian W. Kernighan, Dennis M. Ritchie. The C Programming Language, 2rd Edition.