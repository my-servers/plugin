
# 快速开始

## 服务端
首先安装服务端程序，可选择安装方式有docker直接运行，直接进程运行，各有优缺点，下面详细说明

### 服务端程序运行
提供两种运行方式，建议选择第一中
1. docker

```shell
docker run -it -d --network=host --name=myServers  myservers/my_servers
```
2. 直接运行服务端进程（待完善）


### 配置文件
服务端配置，主要关注，密钥，端口和插件地址
```yaml
RestConfig:
  Name: MyServers
  Host: 0.0.0.0
  Port: 18612
  Log:
    Stat: false
    Level: error
SecretKey: e8edf0cd4c5d49694c39edf7a879a92e
PluginUrl: https://plugin.codeloverme.cn/
MarkdownPage:
  About: https://plugin.codeloverme.cn/about.md
AppDir: apps
Name: codelover

```
- `SecretKey` 是app和服务端通信的密钥，app和服务端保持一致，否则无法通信，可以使用`md5`生成
  - `echo -n "test" | md5`
- `PluginUrl` 插件列表地址，里面是所以的可运行的插件
- `RestConfig.Port` 端口
- `AppDir` 服务端脚本保存的目录


## 客户端

1. 切换到服务器
2. 点击`+`添加
3. 主要关注ip和端口，密钥（需要和上面服务端一致）


更多特性请访问[MyServers官网](https://myservers.codeloverme.cn)

