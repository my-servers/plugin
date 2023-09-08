# 快速开始

## 服务端
首先安装服务端程序，可选择安装方式有docker直接运行，直接进程运行，各有优缺点，下面详细说明

### docker运行
docker运行，方便快捷，一行命令就能run起来
```shell
docker run -it -d myServers/myServers
```

### 直接进程运行
- 下载编译好的二进制文件，或者直接源码编译（2选1）
  1. 下载地址：
  2. 源码地址：
  3. 编译命令：
- 运行命令


### 配置文件
```yaml
RestConfig:
  Name: MyServer
  Host: 0.0.0.0
  Port: 8888
  Log:
    Stat: false
    Level: error
SecretKey: xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
PluginUrl: https://services.codeloverme.cn/
AppDir: apps
Name: codelover

```
- `SecretKey`是app和服务端通信的密钥，app和服务端保持一致，否则无法通信
- `PluginUrl`支持的服务地址，可以自定义，但是具体协议请参考 todo
- `AppDir`服务端脚本保存的目录

更多特性请访问[MyServers官网](https://myservers.codeloverme.cn)