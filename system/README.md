# system 管理

> 🎉🎉🎉新增文件管理功能，升级客户端和服务端体验，版本要求服务端v1.1，客户端v1.4
- ![](https://plugin.codeloverme.cn/system/file.png)


## 插件界面
![](https://plugin.codeloverme.cn/system/all.png)

## 插件配置
- 长按展示界面
- ![](https://plugin.codeloverme.cn/system/config.png)
- `nas`挂载点：可以把外部的`nas`目录映射到容器中，这样就可以监控`nas`的存储使用情况，默认是根目录
  - 比如上面就是通过把外部的nas文件映射到容器的`/nas`，配置这个目录就行
- 网络接口：选择机器上的接口名，关注上传下载速度
- `cpu`走势图大小：当前监控视图保留的点的个数


## 功能
- 监控系统运行情况
- 运`行shell`命令
  - **注意，如果跑在容器中，那么命令是在容器中运行的**


-------------------

> 下面的内容是上面配置界面对应的配置文件，可以不用关心，App上修改就行，无需手动在服务端修改。
## 配置
```yaml
extend:
  CpuWin:
    val: "100"
    desc: cpu走势图窗口大小
    priority: 0
  Interface:
    val: eth0
    desc: 网络接口
    priority: 90
  Disk:
    val: /
    desc: nas挂载点
    priority: 100

``` 


