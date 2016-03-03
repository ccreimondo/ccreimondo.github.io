# An Overview of Unix Kernels

## The User/Kernel Model
Q1. 一个程序哪部分在 User Space 执行，哪部分在 Kernel Space 执行？
有如下程序:
```c
int fact(n) {
    return ((n == 2) ? 2 : n * f(n - 1))
}

int main() {
    int rv = fact(10);
    
    return 0;
}
```
