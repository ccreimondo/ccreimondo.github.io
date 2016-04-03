# Memory Architecture in Linux

## Paging
Linux采用四级分页模型（PGD, [PUD, PMD,] PT)。其中页大小取决于线性地址中的offset位数，典型的，Linux使用12bits，即页大小为4KB。

## Setup Memory
Linux启动过程中，借住BIOS构建物理地址映射。内核代码（text）、数据（data）占据物理内存前3MB RAM（包括保留空间）。
线性地址以0xc0000000分界，低地址为内核态进程可寻址空间。内核创建并维护自己的页表（master kernel PGD)。
借助这些页中的数据，内核便可进行线性地址到物理地址的转换。