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

------------

## 插件界面

![](https://plugin.codeloverme.cn/qbittorrent/all.png)


## 插件配置

- 长按展示界面
  - ![](https://plugin.codeloverme.cn/qbittorrent/config.png)
- 根据后端服务器配置的来填写，主要关心用户名，密码，ip和端口



## 功能
- 新增下载（添加磁链接）
- 管理下载任务，**长按**每个下载任务可以拉起菜单
  - ![](https://plugin.codeloverme.cn/qbittorrent/menu.jpg)
- 查看下载进度，详情等，**点击**任务查看详情
  - ![](https://plugin.codeloverme.cn/qbittorrent/detail.png)
- 搜索下载
  - 需要在服务端安装好搜索插件


-------------------

> 下面的内容是上面配置界面对应的配置文件，可以不用关心，App上修改就行，无需手动在服务端修改。
## 配置文件

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

