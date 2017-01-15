---
layout: post
title:  "Python Date & Time and gettimeofday() in Linux"
date:   2016-4-27 00:00:00
categories: python
---

简单说下 Python 关于时间管理的一些常见问题及时间在 Linux 内核中的体现。


## 时间标准和时间表示法
其分别对应于 UTC 和 ISO 8601。UTC 是最主要的世界时间标准，且区分时区。比如，我
们的算法地时间即东八区（UTC+8)。ISO 8601 是日期和时间表示的国际标准。我们可以简
单理解为它规定了时间中每部分的位数和分隔符号，e.g. YYYY-MM-DDTHH:MM:SSZ，其中
T 为合并日期和时间时的分隔字符，Z 后缀表示该时间为 UTC。我们写程序时，意识到以
上两个标准是有必要的。


## UNIX 时间和 UTC
在 unix 中，时间是以偏移量的形式存在的，而这个偏移量的起点即
1970-1-1T00:00:00Z。Unix 时间即从协调世界时 1970 年 1 月 1 日 0 时 0 分 0 秒起
至现在的总秒数。这样，我们又多了一个时间的表示法，unix 时间戳（timestamp）。


## System Call: `gettimeofday()`
Linux 系统调用 `gettimeofday()` 返回 unix 时间戳及在前一秒内走过的纳秒数。内核
维护了一个 xtime，类型如下：

~~~c
struct timespec {
        __kernel_time_t tv_sec;     /* seconds */
        long            tv_nsec;    /* nanoseconds */
};

~~~

我们看到，它精确到了纳秒。内核通过 RTC（硬件模块）初始化 xtime 并通过周期性时钟中
断更新 xtime。`gettimeofday()` 便是通过它返回时间戳。


## Timestamp to Datetime
Python 中，我们常用到标准库中的 datetime 和 time 模块。datetime 提供了操作日期
和时间的类、方法。time 用于获取当前的 timestamp。我们可以按如下方法创建一个本地当
前时间的 datetime 对象：

~~~python
from datetime import datetime
import time

curr_datetime = datetime.fromtimestamp(time.time())
~~~

然而，datetime 直接有封装好的方法：

~~~python
from datetime import datetime

curr_datetime = datetime.now()
~~~

如何将一个特定的 datetime 变成 timestamp？

~~~python
from datetime import datetime
import time

curr_datetime = datetime.now()
timestamp = time.mktime(curr_datetime.timetuple())
~~~

如何将一个 datetime 输出 ISO 8601 格式？datetime 自带相关方法:

~~~python
from datetime import datetime

curr_datetime = datetime.now()
print curr_datetime.isoformat()
# 2016-04-28T01:31:51.634795
~~~

当然，我们完全可以自定义时间格式，然后调用 `datetime.strftime(format)` 得到我们
想要的时间形式。


## References
- [Coordinated Universal Time; Wikipedia.](https://en.wikipedia.org/wiki/Coordinated_Universal_Tim://en.wikipedia.org/wiki/Coordinated_Universal_Time)
- [ISO 8601; Wikipedia.](https://zh.wikipedia.org/wiki/ISO_8601)
- [Unix Time; Wikipeida.](https://en.wikipedia.org/wiki/Unix_time)
- [Dates and Times; Python Doc.](https://docs.python.org/2/tutorial/stdlib.html#dates-and-times)
- Understanding the Linux Kernel.

