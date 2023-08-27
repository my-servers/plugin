# system 管理

## 配置
```yaml
name: 系统监控
enable: true
priority: 100
padding: 3
extend:
  CpuWin:
    val: "100"
    desc: cpu走势图窗口大小
    priority: 0
  Interface:
    val: enp7s0f1
    desc: 网络接口
    priority: 90
  Disk:
    val: /
    desc: nas挂载点
    priority: 100

height: 4
``` 

- `CpuWin`
  - `cpu`走势图监控的窗口大小(最大记录点的个数)
- `Interface`
  - 网络接口名，用来统计上传下载网速大小
- `Disk`
  - 监控的磁盘使用情况，填任意该磁盘下的目录

## 脚本运行
- 支持运行任意服务端命令
- 不支持阻塞式命令
- **如果服务端运行在docker，那么执行的位置是在容器中**