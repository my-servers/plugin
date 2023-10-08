#  transmission 管理

## 先在服务端运行transmission

```shell
docker run -d \
  --name=transmission \
  -e PUID=1000 \
  -e PGID=1000 \
  -e TZ=Shanghai/China \
  -e TRANSMISSION_WEB_HOME=/transmission-web-control/ \
  -e USER=username \
  -e PASS=password \
  -p 9091:9091 \
  -p 51413:51413 \
  -p 51413:51413/udp \
  -v /root/transmission/config:/config \
  -v /root/transmission/downloads:/downloads \
  -v /root/transmission/watch:/watch \
  --restart unless-stopped \
  linuxserver/transmission
```
- 配置登录用户和密码
- 具体配置请参考transmission的官方文档



## 配置

```yaml
  HostPort:
    val: http://username:password@127.0.0.1:9091
    desc: ip和端口（含用户密码）
    priority: 180
  DownloadPath:
    val: /downloads
    desc: 下载路径
    priority: 170
```

- `HostPort` 用户名密码和地址
  - `http://username:password@127.0.0.1:9091`


## 功能
- 新增下载
- 管理下载任务
- 查看下载进度，详情等
