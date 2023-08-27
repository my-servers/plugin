# docker 管理

## 配置
### 接口
- 指定ip和端口 `http://127.0.0.1:6666`

## 功能
### 镜像
- 搜索
- 拉取
### 容器
- 启动
- 运行
- 停止

```yaml
name: docker
enable: true
priority: 80
height: 6
padding: 3
extend:
  HostPort:
    val: "http://127.0.0.1:6666"
    desc: 接口
    priority: 200
```

![img](https://plugin.codeloverme.cn/qbittorrent/qbittorrent.jpg)