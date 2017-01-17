# spf13-vim Tips
接触了下 spf13-vim，配置组织的不错，就直接拿来用了。这里做一些使用笔记，也记录一些
插件的使用方法。

## Configuration Dependence

See official [illustration](https://github.com/spf13/spf13-vim).


## Surround
A tool for dealing with pairs of "surroundings", like parentheses, quotes, and 
HTML tags.

- `ds])`
- `cs])`
- `ysiw]` (w = word, W = WORD, s = sentence)


## NERDTree
Launch using <Leader>e.


Customizations:
- Use <c-e> to toggle NERDTree
- Use <leader>e or <leader>nt to open NERDTree where the current file is located


## CTags & Tagbar

- 'ctags -R -f .tags'
- `<c-]>` to jump to its definition, `<c-t>` to jump back up one level
- spf13-vim binds `<Leader>tt` to toggle the Tagbar panel
- `:set tags?` to see tag file path, and `:set tags+=./.tags` to add a path

`:tag /^sth_*` would find all tags matches the re. and give a list
- `:ts` or `:tselect` show the list
- `:tn` or `:tnext` goes to the next tag in that list
- `:tp` or `:tprev` goes to the previous tag in that list
- `:tf` or `:tfirst` goes to the first tag of the list
- `:tl` or `:tlast` goes to the last tag of the list


## ctrlp
Launch using <c-p>.


## Fugitive
pass


## Undotree
Launch using `<Leader>u`.


## AutoClose
pass


## References

- [spf13-vim doc](https://github.com/spf13/spf13-vim)
- [VIM and CTags](https://andrew.stwrt.ca/posts/vim-ctags://andrew.stwrt.ca/posts/vim-ctags/)
