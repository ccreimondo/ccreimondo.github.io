---
layout: post
title:  "Gitlab Install and Nginx Proxy"
date:   2015-11-21 15:22:00
categories: howto nginx
---

- 探索 nginx reverse proxy feature.
- 探索 nginx mail proxy feature.
- Gitlab CE 安装。

## Target
Browser <--HTTP--> PS (Public Server with Nginx) <--HTTP--> LS (Local Server with Gitlab, Nginx bundled)

## Problem 0x00
登陆请求一直返回`422 Unprocessable Entity`. 页面提示**422 The change you requested was rejected.**
翻翻 `gitlab-rails/production.log` 看到 `Can't verify CSRF token authenticity`. What's CSRF? See [csrf@wooyun](http://wiki.wooyun.org/web:csrf).

感觉碰到坑点 [See](https://gitlab.com/gitlab-org/gitlab-ce/issues/1511).


