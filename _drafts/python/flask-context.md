# Flask Context
本笔记初衷是弄清楚flask.g的生命周期。


## Thread Safe
线程安全指某个函数在多线程环境中被调用时能正确处理多个线程之间的共享变量。


## Thread-local Storage
我们知道线程组间是共享地址空间的，只是拥有不同的栈。TLS可以让线程拥有自己的存储空间，方便（保证线程安全）线程内的函数之间共享数据。


## The Application Context
- Flask APP有两个状态，初始化状态（没任何request）、请求处理状态（有请求上下文，flask.request等对象指向当前请求）。
- Flask应用上下文用于区分同一个进程中不用的APP。
- Flask应用上下文不会在不同的线程、请求间共享。flask.g是应用上下文中的一个对象，那么它在每个请求中都是不同的。


## Reference
- [The Application Context. Flask.](http://flask.pocoo.org/docs/0.10/appcontext/)