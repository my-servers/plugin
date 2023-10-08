#  frp 管理

- 支持frp配置文件管理
- 支持端口探活


```yaml
extend:
  ConfigPath:
    val: "/nas/server/frpc/frpc.ini"
    desc: 配置文件
    priority: 200
  RestartScript:
    val: "docker restart frpc"
    desc: 重启脚本
    priority: 201

```
- `ConfigPath` frp的配置文件目录
- `RestartScript` 配置更新后的重启脚本

