# qbittorrent 管理

## 先在服务端运行qbittorrent

```shell
docker run -d \
  --name=qbittorrent \
  -p 7881:7881 \
  -p 7881:7881/udp \
  -p 18080:18080 \
  -v /data/qbittorrent/config:/etc/qBittorrent \
  -v /data/qbittorrent/downloads:/downloads \
  --restart unless-stopped \
  helloz/qbittorrent
```
- 配置登录用户和密码
- 具体配置请参考qbittorrent的官方文档


## 配置

```yaml
name: qBittorrent
enable: true
priority: 90
height: 6
padding: 3
extend:
  ColNum:
    val: "2"
    desc: 展示多少列
    priority: 200
  NameLen:
    val: "20"
    desc: 名字长度限制
    priority: 210
  Username:
    val: username
    desc: 用户名
    priority: 200
  Password:
    val: password
    desc: 密码
    priority: 190
  HostPort:
    val: http://127.0.0.1:18080
    desc: ip和端口
    priority: 180
  SearchNum:
    val: "20"
    desc: 搜索展示数量
    priority: 170
```

- `HostPort` ip和端口
  - `http://127.0.0.1:18080`
- `Username` 上面设置的用户名
- `Password`上面设置的密码


## 功能
- 新增下载
- 管理下载任务
- 查看下载进度，详情等
