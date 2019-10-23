# 在linux中添加一个系统调用


## 系统调用`get_thread_size` 
该系统调用会返回当前thread的内核栈大小。我们将在kernel/sys.c里实现它，源码如下：

```c
#include <asm/page.h>
asmlinkage long sys_get_thread_size(void)
{
        return THREAD_SIZE;
}
```

## 注册新系统调用

1. 在x86/kernel/syscall_table_32.S添加`.long sys_get_thread_size`
2. 在asm/unistd_32.h中为该新系统调用定义系统调用号并修改NR_syscalls:

```c
#define __NR_get_thread_size    337

#ifdef __KERNEL__
#define NR_syscalls 338
...
#endif	/* __KERNEL__ */
```
3. 编译并安装内核（不用安装内核头文件）

## 测试新系统调用
我们可以借用glibc提供的`syscall()`（`_syscalln()`是不需要glibc支持的，但它从2.6.18就被移除了）在用户空间调用系统调用。`syscall(int number, ...)`的第一个参数为系统调用号，后跟系统调用的参数。我们关于调用get_thread_size的源码如下：

```c
/* test_syscall.c */
#include <stdio.h>
#include <unistd.h>

#define __NR_get_thread_size 337


int main()
{
        long stack_size;

        stack_size = syscall(__NR_get_thread_size);
        printf("The kernel stack size is %ld.\n", stack_size);

        return 0;
}
```

输出结果：

```bash
root@ubuntu:~/khack/ctest# gcc test_syscall.c -o test_syscall.out
root@ubuntu:~/khack/ctest# ./test_syscall.out
The kernel stack size is 8192.
```

至此，我们成功地在内核中添加了一个系统调用。
以上。
