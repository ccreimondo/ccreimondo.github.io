# VIM Tips
学习 VIM 最好资源就是其文档，`:help`。这里是一篇笔记，基于使用频率。


## Tab & Space

```vimscript
:set et sts=4 sw=4 ts=4
" et  = expandtab (spaces instead of tabs)
" ts  = tabstop (the number of spaces that a tab equates to)
" sw  = shiftwidth (the number of spaces to use when indenting or de-indenting a line)
" sts = softtabstop (the number of spaces to use when expanding tabs)
```


## Folding
See `:help fold`.


## Using hidden buffers
See `:help ls`.

- `:ls` for list of open buffers
- `:bp` previous buffer
- `:bn` next buffer
- `:bn` (n is a number) movet to n'th buffer
- `:b <filename part>` with tab-key providing auto-completion


## Copy & Paste

- `p` `yy`
- `p` vs `P`


## Repeat last command

- `.`
- `@:`


## Show settings

- `:set compatible?` to check a specific one


## Resize window
