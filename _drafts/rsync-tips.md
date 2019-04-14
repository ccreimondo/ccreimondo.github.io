# Use `rsync` to Backup my Files

```bash
# `workspace/` means copy files in `workspace/` to `dst/`
ABS_PATH="/home/rh/workspace/"
SRC="root@192.168.1.140:$ABS_PATH"
DST="/hdd/backup/ser140/$ABS_PATH"

# Same as the name
$ mkdir -p $DST

# Concerned options:
#	-a, --archive 归档模式，表示以递归方式传输文件，并保持所有文件属性，等于 -rlptgoD
#	-v, --verbose 详细模式输出
#	-z, --compress 对备份的文件在传输时进行压缩处理
#	-h, --human-readable 输出友好
#	-P, --partial 保留那些因故没有完全传输的文件，以是加快随后的再次传输
# 	--delete 删除那些 DST 中 SRC 没有的文件
#	--progress 显示备份过程
RSYNC="rsync -avzh --partial --progress --delete $SRC $DST"

# Add logging and notification features
LOG=ser140_rh_workspace.rsync.$(date +%Y-%m-%d-%H-%M-%S).log
SUC_MSG="Successfully backup your workspace in ser140."
ERR_MSG="Failed to backup your workspace in ser140! See log for details."
for _ in $(seq $NR_REPEATS); do
    $RSYNC >$LOG 2>&1 && { rm $LOG && notify-send "$SUC_MSG" && break; } || \
    	notify-send -u critical "$ERR_MSG"
done

# Add to crontab to backup my files at 2a.m. everyday
0   2   *   *   *   rh  test -f /hdd/backup/ser140_rh_workspace_backup.sh && bash /hdd/backup/ser140_rh_workspace_backup.sh
```

## Refs

- 使用 rsync 增量备份文件. http://einverne.github.io/post/2017/07/rsync-introduction.html.
- How to create a message box from the command line? https://unix.stackexchange.com/questions/144924/how-to-create-a-message-box-from-the-command-line.