# docker 管理

## 插件界面
![](https://plugin.codeloverme.cn/docker/all.png)


## 插件配置
- 长按展示界面
- ![](https://plugin.codeloverme.cn/docker/config.png)
- 需要docker服务开启http端口
  - 修改 `/lib/systemd/system/docker.service` 项 `ExecStart`新增监听`http`
  - 示例：`ExecStart=/usr/bin/dockerd -H tcp://127.0.0.1:6666 -H fd:// --containerd=/run/containerd/containerd.sock`




## 功能

### 镜像

- 搜索
- 拉取
- 删除

### 容器
- ![](https://plugin.codeloverme.cn/docker/menu.jpg)
- 查看详情
  - ![](https://plugin.codeloverme.cn/docker/detail.png)
- 启动
- 运行
- 停止


-------------------

> 下面的内容是上面配置界面对应的配置文件，可以不用关心，App上修改就行，无需手动在服务端修改。

## 配置

```yaml
HostPort:
  val: "http://127.0.0.1:6666"
  desc: 接口
  priority: 200

```
