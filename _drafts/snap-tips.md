# Tips on snap Usage

## Add proxy

```bash
$ sudo systemctl edit snapd.service
```

Add in the following:
```
[Service]
Environment=http_proxy=http://localhost:1081
Environment=https_proxy=http://localhost:1081
```

Save then reload:
```bash
$ sudo systemctl daemon-reload
$ sudo systemctl restart snapd
```

## Refs
- Snap proxy doesn't work. https://stackoverflow.com/questions/50584084/snap-proxy-doesn%C2%B4t-workhttps://stackoverflow.com/questions/50584084/snap-proxy-doesn%C2%B4t-work.
