# sys_open
open()系统调用的服务例程为sys_open()函数，该函数接受的参数为：要打开的路径名filename、
访问模式的一些标志flags，以及如果该文件被创建所需要的权限掩码mode。如果该系统调用成功，就
返回一个文件文件描述符，也就是指向文件对象指针数组current->files->fd中分配给新文件的索引；
否则，返回-1。


## 原理分析
进程不直接与磁盘上的文件系统交互，而是与VFS交互，VFS再与具体的文件系统交互。sys_open的过程
反应了VFS中各个数据结构间的相互作用，也涉及VFS与具体文件系统的交互。

作为通用文件模型，VFS抽象出superblock对象、inode对象（CSAPP称为vnode）、file对象和
dentry对象：
- superblock: 存放已安装文件系统的有关信息，e.g. 对应于fs控制块，sb.inodes为所有索引节点
的链表；
- inode: 存放关于具体文件的一般信息，e.g. 对应于EXT4的inode，inode.i_size为文件字节数；
- dentry: 描述一个目录的信息。e.g. dentry.d_subdirs为子目录链表；
- file: 描述当前进程打开的文件的状态，e.g. file.f_pos记录位移量。
当一个具体的磁盘文件系统被挂载和访问时，VFS会根据该磁盘文件系统中的信息（超级块和inode）
在内存中构造出包含以上元素的更加丰满、高效和符合我们认知的文件系统。不同于磁盘中文件系统的
控制信息，VFS中的数据结构都是动态创建的且数量有限，e.g.dentry在文件第一次被访问时创建，
不用的dentry会被回收。

task_struct中与文件系统相关的变量有fs和files。fs维护着进程当前的根目录项和工作目录项，目
录所在文件系统等信息。files维护着进程当前打开的文件对象，如图：
![files_of_process](images/files_of_process.png)
若一个进程想打开一个文件，它便调用open系统调用。sys_open首先解析文件路径，如将/usr/src/
linux/fs/open.c解析为/、usr、src、linux、fs和open.c。然后从current->fs中的root或pwd
所标示的目录项开始搜索，直到找到open.c的目录项。dentry中有指向open.c的inode指针，inode
存有该文件的属性和文件数据。sys_open会创建一个file对象并关联到open.c的目录项。最后，
sys_open将file对象的指针存在current->files中的打开文件数组中，并返回它的索引。


## 源码分析

```c
/* kernel/fs/open.c */
SYSCALL_DEFINE3(open, const char __user *, filename, int, flags, int, mode)
{
	long ret;

/* struct file中的off_t为long，32位机器上我们只能访问2G以内的文件。设置O_LARGEFILE可以
在32位机器上使用off64_t，即访问超过2G的文件。*/
	if (force_o_largefile())
		flags |= O_LARGEFILE;
/* 调用do_sys_open。其中，第一个参数dfd会在path_init中使用，AT_FDCWD标明非绝对路径从当
前工作目录开始搜索 */
	ret = do_sys_open(AT_FDCWD, filename, flags, mode);
	/* avoid REGPARM breakage on x86: */
	asmlinkage_protect(3, ret, filename, flags, mode);
	return ret;
}
```

```c
/* kernel/fs/open.c */
long do_sys_open(int dfd, const char __user *filename, int flags, int mode)
{
/* getname从slab中的names_cachep中分配一个names对象并从进程地址空间拷贝文件路径到
names中 */
	char *tmp = getname(filename);
/* PTR_ERR将tmp指针强制转换为long并将其看成默认的错误码 */
	int fd = PTR_ERR(tmp);
/* IS_ERR依据内核地址空间的范围检查tmp指针的合法性 */
	if (!IS_ERR(tmp)) {
/* 调用get_unused_fd_flags从当前进程的fd_set中获取一个空闲的fd，flags中的O_CLOEXEC
指明fd在执行exec()时需要被关闭 */
		fd = get_unused_fd_flags(flags);
		if (fd >= 0) {
/* 调用do_filep_open以打开指定路径的文件，返回file对象的指针 */
			struct file *f = do_filp_open(dfd, tmp, flags, mode, 0);
			if (IS_ERR(f)) {
/* 若f指针无效，归还fd并设置错误码为(long)f */
				put_unused_fd(fd);
				fd = PTR_ERR(f);
			} else {
/* 在fsnotify中注册f的open事件 */
				fsnotify_open(f->f_path.dentry);
/* 等效于fd_array[fd] = f */
				fd_install(fd, f);
			}
		}
/* 将names对象归还给slab中的names_cachep */
		putname(tmp);
	}
	return fd;
}
```

```c
/* include/linux/path.h */
struct path {
	struct vfsmount *mnt;
	struct dentry *dentry;
};

/* include/linux/namei.h */
struct nameidata {
	struct path	path;	   	/* 文件路径，由文件的dentry和该文件所在文件系统的vfsmount组成 */
	struct qstr	last;		/* 路径名的最后一个分量（当LOOKUP_PARENT标志被设置时使用）, e.g. 'open.c' */
	struct path	root;		/* 文件父目录路径 */
	unsigned int	flags;		/* 查找标志 */
	int		last_type;	/* 路径名的最后一个分量的类型（使用场景同last）*/
	unsigned	depth;		/* 符号链接嵌套的次数 */
	char *saved_names[MAX_NESTED_LINKS + 1];	/* 保存每一个符号链接中的路径 */

	union {
		struct open_intent open;
	} intent;			/* 指定如何访问文件（存有open_flags） */
};

```

```c
/* kernel/fs/namei.c */
struct file *do_filp_open(int dfd, const char *pathname,
		int open_flag, int mode, int acc_mode)
{
	struct file *filp;
	struct nameidata nd;
	int error;
	struct path path;
	struct dentry *dir;
	int count = 0;
	int will_write;
/* flag和open_flag的低2位并不一一对应。open_flag中，低两位分别表示：
 *	00 - read-only
 *	01 - write-only
 *	10 - read-write
 *	11 - special
 * open_to_namei_flags将00->01，01->02，02->03，03->00，低两位分别代表：
 *	00 - no permissions needed
 *	01 - read-permission
 *	10 - write-permission
 *	11 - read-write
 * 除此之外，flag与open_flag相同。
 */
	int flag = open_to_namei_flags(open_flag);

/* 为例程初始化文件访问模式变量acc_mode，默认为打开模式 */
	if (!acc_mode)
		acc_mode = MAY_OPEN | ACC_MODE(flag);

/* 设置文件为可写或者添加模式 */
	if (flag & O_TRUNC)
		acc_mode |= MAY_WRITE;

	if (flag & O_APPEND)
		acc_mode |= MAY_APPEND;

/* 若未设置O_CREATE（当文件不存在时创建新文件）标志时，直接调用path_looup_open搜索指定文件
并跳转到ok */
	if (!(flag & O_CREAT)) {
		error = path_lookup_open(dfd, pathname, lookup_flags(flag),
					 &nd, flag);
/* 若path_lookup_open成功（错误返回相应错误码 e.g. -ENFILE），返回0且将搜索结果填充在nd中 */
		if (error)
			return ERR_PTR(error);
		goto ok;
	}

/* 
 * 若O_CREATE被设置，我们需要先找到文件的父目录以创建新文件。这个过程包括path_init，
 * path_walk。
 */
/* 调用path_init初始化nd中数据结构（设置搜索起点等）并指定LOOKUP_PARENT标志 */
	error = path_init(dfd, pathname, LOOKUP_PARENT, &nd);
	if (error)
		return ERR_PTR(error);
/* 调用搜索函数搜索文件的父目录，返回0表示成功 */
	error = path_walk(pathname, &nd);
	if (error) {
		if (nd.root.mnt)
/* path_get和path_put分别添加和减少指定path的引用计数，以避免path在后期操作被释放。
这里，path_walk返回错误，我们需要减少对nd.root的引用 */
			path_put(&nd.root);
		return ERR_PTR(error);
	}
	if (unlikely(!audit_dummy_context()))
		audit_inode(pathname, nd.path.dentry);

/* TODO: Is there LAST_NORM? */
	error = -EISDIR;
	if (nd.last_type != LAST_NORM || nd.last.name[nd.last.len])
		goto exit_parent;

	error = -ENFILE;
/* 调用get_empty_filp获得一个空闲file对象，若无空闲file对象或内存耗尽，返回NULL */
	filp = get_empty_filp();
	if (filp == NULL)
		goto exit_parent;
/* 初始化nd.intent用于将被打开的文件 */
	nd.intent.open.file = filp;
	nd.intent.open.flags = flag;
	nd.intent.open.create_mode = mode;
/* 从nd中获取文件所在目录的dentry */
	dir = nd.path.dentry;
/* LOOKUP_PARENT用于查找父目录，这里取消它 */
	nd.flags &= ~LOOKUP_PARENT;
/* LOOKUP_CREATE: 试图创建一个文件，LOOKUP_OPEN: 试图打开一个文件 */
	nd.flags |= LOOKUP_CREATE | LOOKUP_OPEN;
/* O_EXCL表示，对于O_CREATE标志，若文件已存在则失败 */
	if (flag & O_EXCL)
		nd.flags |= LOOKUP_EXCL;
	mutex_lock(&dir->d_inode->i_mutex);
/* 调用lookup_hash获取文件的dentry和vfsmount，没有dentry就创建一个 */
	path.dentry = lookup_hash(&nd);
	path.mnt = nd.path.mnt;

do_last:
/* IS_ERR和PTR_ERR分别用于检查指针有效性和根据指针设置错误码 */
	error = PTR_ERR(path.dentry);
	if (IS_ERR(path.dentry)) {
		mutex_unlock(&dir->d_inode->i_mutex);
		goto exit;
	}
	if (IS_ERR(nd.intent.open.file)) {
		error = PTR_ERR(nd.intent.open.file);
		goto exit_mutex_unlock;
	}

	/* Negative dentry, just create the file */
	if (!path.dentry->d_inode) {
		/*
		 * This write is needed to ensure that a
		 * ro->rw transition does not occur between
		 * the time when the file is created and when
		 * a permanent write count is taken through
		 * the 'struct file' in nameidata_to_filp().
		 */
/* 调用mnt_want_write通知低级文件系统将要创建一个文件并检查写入权限 */
		error = mnt_want_write(nd.path.mnt);
		if (error)
			goto exit_mutex_unlock;
/* __open_namei_create会调用vfs_create创建path指定的文件并dentry->d_inode = inode */
		error = __open_namei_create(&nd, &path, flag, mode);
		if (error) {
			mnt_drop_write(nd.path.mnt);
			goto exit;
		}
/* 调用nameidate_to_filp（调用__dentry_open）打开文件并将返回的file指针赋给filp */
		filp = nameidata_to_filp(&nd, open_flag);
		if (IS_ERR(filp))
			ima_counts_put(&nd.path,
				       acc_mode & (MAY_READ | MAY_WRITE |
						   MAY_EXEC));
/* 减少nd.path.mnt和nd.root中dentry和vfsmount的引用计数 */
		mnt_drop_write(nd.path.mnt);
		if (nd.root.mnt)
			path_put(&nd.root);
/* 返回文件指针 */
		return filp;
	}

	/*
	 * It already exists.
	 */
	mutex_unlock(&dir->d_inode->i_mutex);
	audit_inode(pathname, path.dentry);

/* 若O_CREATE|O_EXCL，且path指定文件存在时，需要返回EEXIST错误 */
	error = -EEXIST;
	if (flag & O_EXCL)
		goto exit_dput;

/* __follow_mount检查nd->path->dentry是否是某文件系统的安装点（nd->dentry->d_mounted的值大于0），
该函数最终会更新nd->path->dentry和nd->path->mnt为当前目录挂载的最高层文件系统 */
	if (__follow_mount(&path)) {
		error = -ELOOP;
		if (flag & O_NOFOLLOW)
			goto exit_dput;
	}

	error = -ENOENT;
	if (!path.dentry->d_inode)
		goto exit_dput;
/* 如果path指定的文件是一个链接，调用i_op->follow_link追踪该链接并跳转到do_link */
	if (path.dentry->d_inode->i_op->follow_link)
		goto do_link;

/* 更新nd */
	path_to_nameidata(&path, &nd);
	error = -EISDIR;
	if (path.dentry->d_inode && S_ISDIR(path.dentry->d_inode->i_mode))
		goto exit;
ok:
	/*
	 * Consider:
	 * 1. may_open() truncates a file
	 * 2. a rw->ro mount transition occurs
	 * 3. nameidata_to_filp() fails due to
	 *    the ro mount.
	 * That would be inconsistent, and should
	 * be avoided. Taking this mnt write here
	 * ensures that (2) can not occur.
	 */
	will_write = open_will_write_to_fs(flag, nd.path.dentry->d_inode);
	if (will_write) {
		error = mnt_want_write(nd.path.mnt);
		if (error)
			goto exit;
	}

	error = may_open(&nd.path, acc_mode, flag);
	if (error) {
		if (will_write)
			mnt_drop_write(nd.path.mnt);
		goto exit;
	}
/* 调用nameidate_to_filp（调用__dentry_open）打开文件并将返回的file指针赋给filp */
	filp = nameidata_to_filp(&nd, open_flag);
	if (IS_ERR(filp))
		ima_counts_put(&nd.path,
			       acc_mode & (MAY_READ | MAY_WRITE | MAY_EXEC));
	/*
	 * It is now safe to drop the mnt write
	 * because the filp has had a write taken
	 * on its behalf.
	 */
	if (will_write)
		mnt_drop_write(nd.path.mnt);
	if (nd.root.mnt)
		path_put(&nd.root);
	return filp;

exit_mutex_unlock:
	mutex_unlock(&dir->d_inode->i_mutex);
exit_dput:
	path_put_conditional(&path, &nd);
exit:
	if (!IS_ERR(nd.intent.open.file))
		release_open_intent(&nd);
exit_parent:
	if (nd.root.mnt)
		path_put(&nd.root);
	path_put(&nd.path);
	return ERR_PTR(error);

do_link:
	error = -ELOOP;
	if (flag & O_NOFOLLOW)
		goto exit_dput;
	/*
	 * This is subtle. Instead of calling do_follow_link() we do the
	 * thing by hands. The reason is that this way we have zero link_count
	 * and path_walk() (called from ->follow_link) honoring LOOKUP_PARENT.
	 * After that we have the parent and last component, i.e.
	 * we are in the same situation as after the first path_walk().
	 * Well, almost - if the last component is normal we get its copy
	 * stored in nd->last.name and we will have to putname() it when we
	 * are done. Procfs-like symlinks just set LAST_BIND.
	 */
	nd.flags |= LOOKUP_PARENT;
	error = security_inode_follow_link(path.dentry, &nd);
	if (error)
		goto exit_dput;
	error = __do_follow_link(&path, &nd);
	if (error) {
		/* Does someone understand code flow here? Or it is only
		 * me so stupid? Anathema to whoever designed this non-sense
		 * with "intent.open".
		 */
		release_open_intent(&nd);
		if (nd.root.mnt)
			path_put(&nd.root);
		return ERR_PTR(error);
	}
	nd.flags &= ~LOOKUP_PARENT;
	if (nd.last_type == LAST_BIND)
		goto ok;
	error = -EISDIR;
	if (nd.last_type != LAST_NORM)
		goto exit;
	if (nd.last.name[nd.last.len]) {
		__putname(nd.last.name);
		goto exit;
	}
	error = -ELOOP;
	if (count++==32) {
		__putname(nd.last.name);
		goto exit;
	}
	dir = nd.path.dentry;
	mutex_lock(&dir->d_inode->i_mutex);
	path.dentry = lookup_hash(&nd);
	path.mnt = nd.path.mnt;
	__putname(nd.last.name);
	goto do_last;
}
```