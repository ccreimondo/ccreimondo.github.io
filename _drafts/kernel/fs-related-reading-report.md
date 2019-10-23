# 文件系统相关文章阅读报告
通过此篇报告，我来梳理一些文件系统相关的知识点和研究成果。阅读内容包括几篇会议论文、课本 *Operating Systems: Three Easy Pieces* 和书籍 *Understanding the Linux Kernel*。


## NAND-based Flash and Flash-based SSD [1]
首先简单说一下闪存芯片的特性：在 flash 中，page 为最小的读写单位，block 为最小的擦除/编程（P/E）单位，一个 block 包含若干 page。假如写入的 page 有内容，即使是一个字节，也需要擦除整个 block，然后再写入这个 page 的内容，写入放大问题由此产生；同时，flash P/E 次数有限，频繁地擦写很容易导致芯片损坏。一个 flash-based SSD 由若干闪存芯片组成。SSD 还包括 FTL（Flash Translation Layer），用于将 FS 对逻辑块的读写请求转换成闪存芯片的 Read/Erase/Program 指令。A log-structured FTL 还要完成 address mapping/garbage collection/wear leveling 等功能。


## LFS and F2FS [2]\[3]
不同于 journaling file system 本地更新数据和使用专门的区域记录操作事物, log-structured file system 将改变后的数据追加在硬盘的空闲空间上，再通过修改相关指针来维护文件系统数据的一致性。为提高性能，LFS 以 segment 为单位写回数据。在 LFS 中，inode 的地址不能直接通过 inode number 计算得到，而需要通过 inode map（imap）索引得到。imap 又是借助存储在固定位置的 check-point region（CR）搜索得到。给定一个 inode number，LFS 需要经过 CR->imap->inode 才能访问一个 inode。 LFS 中的一个重要问题就是回收旧数据所占用的硬盘空间，涉及脏块标记、hot/cold segment 标记等。Check-point region 还用于 crash recovery。F2FS 就是一个 LFS。


## 协调文件系统和 FTL [4]\[5]
SSD 通过引入 FTL 将自己抽象成通用块设备，但这种隐藏硬件细节的做法并没有让文件系统充分发挥 SSD 的特性。同时，FTL 和 F2FS 还有一些重复功能 e.g. log-structured/garbage collectio 和一些冲突设计 e.g. hot/cold group vs. internal parallelism。ParaFS 和 AMF 分别通过简化和优化 FTL 设计，让文件系统可以充分利用 SSD 硬件特性。


## 小文件访问优化 [6]
CFFS 一文提及，在桌面系统中，小文件访问操作十分频繁。其中，元数据更新占到一半。所以 CFFS 提出 compsite-file 对小文件的访问进行了优化。CFFS 通过组合小文件以减少冗余元数据和提高 prefetching 的效率。Composite-file 生成的策略包括 directory-based consolidation/embedded-reference consolidation/frequency-mining-baed consolidation。文章作者借助 FUSE 在用户空间实现 CFFS 的做法可以借鉴。在 CFFS 中，如何访问一个 subfile？


## ReconFS [7]
@ReconFS

## `fsync()` 优化 [8]\[9]
`fsync()` 用于将文件系统中所有与特定文件描述符相关的缓冲区数据写会硬盘（包括文件数据和元数据）。文件的元数据保存在 inode 中，包括文件访问权限、文件的 owner/group、时间戳、大小和数据块列表。其中时间戳分为三种：atime（access time）记录文件最后的访问时间，mtime 记录文件最后的修改时间，ctime 记录文件或其 inode 最后的修改时间。一次文件写入不仅更新文件本身的数据，还可能会更新文件的元数据，e.g. atime/mtime/ctime，这会带来较高的开销。EXT4 中，更新的文件文件直接写会硬盘，而更新的文件元数据保存在日志中。一次日志记录会带来额外的写入开销，e.g. a journal head + a updated inode + the block commit block。所以，减少元数据更新可以减少 fsync 时写入开销。对于 mtime/ctime（atime 已有很多优化），[8] 一文提出增加文件系统时间戳的间隔来减少 mtime/ctime 变化的粒度，从而减少文件元数据更新的频率，这样可以减少一次 fsync 所带来的硬盘写入次数，从而提高了了 fsync 的效率。它的算法很简单：

```
// Update the mtime of a file
now ← fs time − (fs time mod interval )
// current time ‘now’ is updated at coarse-grained fs time interval
if mtime ̸= now then
dirty ← 1 	// Set dirty to 1
end if
if dirty = 1 then
mtime ← now // Set mtime to ‘now’
end if
```

## 参考文献

1. [Operating Systems: Three Easy Pieces, Flash-based SSDs.](http://pages.cs.wisc.edu/~remzi/OSTEP/file-ssd.pdf)
2. [Operating Systems: Three Easy Pieces, Log-structured File Systems.](http://pages.cs.wisc.edu/~remzi/OSTEP/file-lfs.pdf)
3. F2FS: A New File System for Flash Storage.
4. ParaFS: A Log-Structured File System to Exploit the Internal Parallelism of Flash Devices.
5. Application-Managed Flash.
6. The Composite-file File System: Decoupling the One-to-one Mappingof Files and Metadata for Better Performance.
7. ReconFS: A Reconstructable File System on Flash Storage.
8. Coarse-grained mtime Update for Better fsync() Performance.
9. Eager Synching: A Selective Logging Strategy for Fast fsync() on Flash-Based Android Devices.
