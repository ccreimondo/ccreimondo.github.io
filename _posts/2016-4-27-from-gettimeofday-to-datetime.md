---
layout: post
title:  "Python Date & Time and gettimeofday() in Linux"
date:   2016-4-27 00:00:00
comments: true
categories: notes linux
---

简单说下Python关于时间管理的一些常见问题及时间在Linux内核中的体现。


## 时间标准和时间表示法
其分别对应于UTC和ISO 8601. UTC是最主要的世界时间标准，且区分时区，e.g. 我们的本
地时间即东八区(UTC+8). ISO 8601是日期和时间表示的国际标准。我们可以简单理解为
它规定了时间中每部分的位数和分隔符号，e.g. YYYY-MM-DDTHH:MM:SSZ，其中T为合并日
期和时间时的分隔字符，Z后缀表示该时间为UTC。我们写程序时，意识到以上两个标准是
有必要的。


## UNIX时间和UTC
在unix中，时间是以偏移量的形式存在的，而这个偏移量的起点即1970-1-1T00:00:00Z.
Unix时间即从协调世界时1970年1月1日0时0分0秒起至现在的总秒数。这样，我们又多了
一个时间的表示法，Unix时间戳(timestamp)。


## System Call: `gettimeofday()`
Linux系统调用`gettimeofday()`返回Unix时间戳及在前1秒内走过的纳秒数。内核维护了
一个`xtime`，类型如下：

~~~c
struct timespec {
        __kernel_time_t tv_sec;     /* seconds */
        long            tv_nsec;    /* nanoseconds */
};

~~~

我们看到，它精确到了纳秒。内核通过RTC(硬件模块)初始化`xtime`并通过周期性时钟中
断更新`xtime`。`gettimeofday()`便是通过它返回时间戳。


## Timestamp to Datetime
Python中，我们常用到标准库中的datetime和time模块。datetime提供了操作日期和时间
的类、方法。time用于获取当前的timestamp. 我们可以按如下方法创建一个本地当前时间
的datetime对象：

~~~python
from datetime import datetime
import time

curr_datetime = datetime.fromtimestamp(time.time())
~~~

然而，datetime直接有封装好的方法：

~~~python
from datetime import datetime

curr_datetime = datetime.now()
~~~

如何将一个特定的datetime变成timestamp?

~~~python
from datetime import datetime
import time

curr_datetime = datetime.now()
timestamp = time.mktime(curr_datetime.timetuple())
~~~

如何将一个datetime输出ISO 8601格式？datetime自带相关方法:

~~~python
from datetime import datetime

curr_datetime = datetime.now()
print curr_datetime.isoformat()
# 2016-04-28T01:31:51.634795
~~~

当然，我们完全可以自定义时间格式，然后调用`datetime.strftime(format)`得到我们
想要的时间形式.


## References
- [协调世界时. Wikipedia.](https://zh.wikipedia.org/wiki/%E5%8D%8F%E8%B0%83%E4%B
8%96%E7%95%8C%E6%97%B6)
- [ISO 8601. Wikipedia.](https://zh.wikipedia.org/wiki/ISO_8601)
- [Unix Time. Wikipeida.](https://en.wikipedia.org/wiki/Unix_time)
- [Dates and Times. Python Doc.](https://docs.python.org/2/tutorial/stdlib.html#dates-and-times)
- Understanding the Linux Kernel

