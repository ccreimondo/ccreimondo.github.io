# `pdf-crop`

Linux 上可以使用 `pdf-crop` 剪裁 PDF 文件。

```bash
$ sudo apt install texlive-extra-utils

# 去除页边距
$ pdfcrop --margins '-5 -10 -5 -10' --clip sheet.pdf

# 添加页边距
$ pdfcrop --margins '5 10 5 10' --clip sheet.pdf
```