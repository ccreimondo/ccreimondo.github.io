# cscope internals

## TL;DR
对于 Linux kernel：

```bash
find -path [path] -name [patterns] -print > cscope.files && \
    cscope -bqk cscope.files
# -k Won't search /usr/include
# -b Build the cross-reference only
# -q Enable fast symbol lookup via an inverted index
```

日常：

```bash
cscope -bqR
# -R means recursively search current directory
```

## Refs
- Using cscope on large projects (example: the Linux kernel). http://cscope.sourceforge.net/large_projects.html.
