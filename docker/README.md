# docker 管理

## 配置

```yaml
HostPort:
  val: "http://127.0.0.1:6666"
  desc: 接口
  priority: 200

```

- `HostPort` 需要docker服务开启http端口
  - `http://127.0.0.1:6666`
- 修改 `/lib/systemd/system/docker.service` 项 `ExecStart=/usr/bin/dockerd -H tcp://127.0.0.1:6666 -H fd:// --containerd=/run/containerd/containerd.sock`

## 功能

### 镜像

- 搜索
- 拉取

### 容器

- 启动
- 运行
- 停止
