
# 快速开始

## 服务端
首先安装服务端程序，可选择安装方式有docker运行和直接进程运行

### docker

1. **宿主机**准备插件目录，为了防止后续升级服务端后插件丢失，建议插件存放在宿主机上，通过文件目录映射共享给容器`mkdir /xx/to/apps`
2. **宿主机**准备准备配置文件`touch /xx/to/config.yaml` `vim /xx/to/config.yaml` 内容如下

```
RestConfig:
  Name: MyServers
  Host: 0.0.0.0
  Port: 18612
  Log:
    Stat: false
    Level: error
SecretKey: 修改我（echo -n "test" | md5）
PluginUrl: https://plugin.codeloverme.cn/
MarkdownPage:
  About: https://plugin.codeloverme.cn/about.md
AppDir: apps
Name: codelover
```

- `SecretKey` 是app和服务端通信的密钥，app和服务端保持一致，否则无法通信，可以使用`md5`生成
  - `echo -n "test" | md5`
- `PluginUrl` 插件列表地址，里面是所以的可下载的插件
- `RestConfig.Port` 端口
- `AppDir` 服务端脚本保存的目录

3. 运行容器，指定参数
- 映射插件目录 `-v /xx/to/apps:/apps`
- 映射配置文件 `-v /xx/to/config.yaml:/app/config/config.yaml`(可选)
- 指定插件目录，如果不指定则使用配置文件中的 `-e AppDir=/apps`
- 指定密钥，如果不指定则使用配置文件中的 `-e SecretKey=e8edf0cd4c5d49694c39edf7a879a92e`

```shell
docker run -it -d --network=host --name=myServers -v /xx/to/apps:/apps  -e AppDir=/apps -e SecretKey=e8edf0cd4c5d49694c39edf7a879a92e myservers/my_servers
```

4. 登录容器修改和查看
```shell
docker exec -it {id} sh
```

5. 修改后重启容器
```shell
docker restart {id} 
```

### 直接运行服务端进程（待完善）


## 客户端

> 客户端的主要操作有**长按**和**点击**两种

### 1. 添加服务器
- 先到**服务器**界面，**点击**`+`添加
- ![](https://myservers.codeloverme.cn/img/add_server.jpeg)
- 填写名字（随意），ip端口，密钥（和服务端对齐），`提交`
- 填写**后点**击选中

### 2. 安装插件到服务器
- 到**服务**界面
- ![](https://myservers.codeloverme.cn/img/add_plugin.png)
- **长按**想要安装的插件，**点击**`启用`

### 3. 再到应用界面
- **长按**已经启用的应用进行`配置`，每个插件有不同的配置，具体**点击**应用会有说明
- ![](https://myservers.codeloverme.cn/img/config_app.png)

更多特性请访问[MyServers官网](https://myservers.codeloverme.cn)

