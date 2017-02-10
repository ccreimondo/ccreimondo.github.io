# File System
Traits: consistence and persistence


## Layers

```
-----------------------------------------------------
open/close/create/unlink
read/write/stat
mkdir/rmdir/chdir etc.
VFS: sb/inode/file/dentry
    -----------------------------------
----|page cache: many buffers per page|--------------
    -----------------------------------
Mapping: LA -> PA
-----------------------------------------------------
BIO
-----------------------------------------------------
Driver
-----------------------------------------------------
```

### VFS

```
task_struct:
struct fs_struct                *fs;
struct files_struct             files;

fs_struct:
struct path                     pwd, root;

path:
struct vfsmount                 *mnt;
struct dentry                   *dentry;

files_struct:
struct fdtable                  *fdt;
struct file                     *fd_array[NR_OPEN_DEFAULT];

file:
struct path                     f_path;
const struct file_operations    *f_op;

dentry:
struct dentry                   *d_parent;
struct inode                    *d_inode;
const struct dentry_operations  *d_op;
struct super_block              *d_sb;
struct list_head                d_child;
struct list_head                d_subdirs;

inode:
const struct inode_operations   *i_op;
struct super_block              *i_op;
struct address_space            *i_mapping;
struct address_space            *i_data;
```

### Cache
inode, dentry and block cache.

### Instance: read or write
pass


## EXT4
This part focus on source reading or scanning.

### Parts
pass

### Journaling
pass

### Problems
pass


## Flash storage features
See paper.


## F2FS
See paper.


## Useful utilities

- FIO
- Postmark
- IOZone

## References

- [文件系统](http://www.voidcn.com/blog/sdulibh/article/p-5001878.html)
