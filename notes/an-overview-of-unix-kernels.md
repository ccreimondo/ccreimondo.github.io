# An Overview of Unix Kernels


## The User/Kernel Model
- 用户进程通过system call从用户态转换到内核态。内核态的进程（也称例程，kernel routine）。
- 例程是处于内核态的进程（因为此时，CPU执行的是内核的某些代码）。它会在如下情况下运行：
  - System Call
  - Exception & Interrupt
  - Kernel Thread
- 除了用户进程，还有几个内核线程（kernel thread），然后再也没有其它形式的进程了。


## Reentrant Kernels & Kernel Control Path
pass


## Q&A
Q1.在以下程序中，哪些部分在user space执行，哪部分在kernel space执行？

```c
int fact(n) {
    return ((n == 2) ? 2 : n * f(n - 1))
}

int main() {
    int rv = fact(10);
    
    return 0;
}
```
