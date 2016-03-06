# Process in Linux

## Memory Architecture of Process
### Paging
Linux 采用四级分页模型 (PGD, [PUD, PMD,] PT)。 其中 Page Size 取决于线性地址中的 offset 位数，典型的，Linux 使用 12bits，即页大小为 4KB。
### Setup Memory
Linux 启动过程中，借住 BIOS 构建物理地址映射。内核代码（text）、数据（data）占据物理内存前 3MB RAM（包括保留空间）。线性地址以 0xc0000000分界，低地址为内核态进程可寻址空间。内核创建并维护自己的页表（master kernel PGD)。借助这些页中的数据，内核便可进行线性地址到物理地址的转换。
### Allocating the Process Descriptor
### Try to Trace Process Kernel Stack

## Process-covered Files

## Process Descriptor

## References
1. Daniel P. Bovet, Marco Cesati. Understanding the Linux Kernel, 3rd Edition.
