
# 快速开始

## 整体架构
[![](https://plugin.codeloverme.cn/img/myservers.png)](https://plugin.codeloverme.cn/img/myservers.png)

## 大致步骤

[![](https://plugin.codeloverme.cn/img/jiaocheng.png)](https://plugin.codeloverme.cn/img/jiaocheng.png)

## 详细步骤

### [1.添加服务器](https://plugin.codeloverme.cn/img/1_add_server.png)
[![](https://plugin.codeloverme.cn/img/1_add_server.png)](https://plugin.codeloverme.cn/img/1_add_server.png)
- 推荐添加ssh后一键安装服务端
- 服务端运行需要docker，请先手动安装
- 长按服务器可进行配置，重新安装服务端会自动换密钥
- 下拉选项数据可以方便选择输入数据
- 终端运行中不要关闭
### [2.安装配置插件](https://plugin.codeloverme.cn/img/2_add_server.png)
[![](https://plugin.codeloverme.cn/img/2_add_server.png)](https://plugin.codeloverme.cn/img/2_add_server.png)
- 系统监控会自动安装
- 其他插件在插件页面进行安装
- 长按可进行删除

### 问题自查步骤

#### 1.检查ssh是否能登陆
- 首先确保ssh可以正常登陆，安装和升级MyServers的服务端，都是需要登陆终端运行升级脚本的 

#### 2.检查docker是否已经运行
- 目前MyServers的服务端是基于docker运行的，需要先手动安装docker
- 如果出现下面的报错，说明ssh登陆的用户没有操作docker的权限，[需要把当前用户加到docker组](https://stackoverflow.com/questions/47854463/docker-got-permission-denied-while-trying-to-connect-to-the-docker-daemon-socke)
```shell
Got permission denied while trying to connect to the Docker daemon socket at unix:///var/run/docker.sock
```

- 添加当前用户到docker组
```shell
sudo usermod -a -G docker $USER
```

```shell
# 查看docker命令
[root@codelover myServer]# docker version
Client: Docker Engine - Community
 Version:           20.10.21
 API version:       1.41
 Go version:        go1.18.7
 Git commit:        baeda1f
 Built:             Tue Oct 25 18:02:19 2022
 OS/Arch:           linux/amd64
 Context:           default
 Experimental:      true
# 查看docker是否启动
[root@codelover myServer]# docker ps
CONTAINER ID   IMAGE                      COMMAND                  CREATED        STATUS                PORTS                                                                                                                                     NAMES
18c519acd12d   myservers/my_servers       "/app/app -k d85c99a…"   14 hours ago   Up 14 hours                
```

#### 3.检查MyServers的服务端是否运行

```shell
[root@codelover myServer]# docker ps | grep myServers
18c519acd12d   myservers/my_servers       "/app/app -k d85c99a…"   14 hours ago   Up 14 hours                                                                                                                                                     myServers
```

#### 4.检查App的端口（默认18612）密钥是否和MyServers服务端一致
```shell
[root@codelover myServer]# cat ~/.myservers/config/config.yaml 

# 最后一行是密钥
SecretKey: d85c99a728dd5066cd565c0c645407ec
```




## QA
### 1. 若安装失败，可手动运行安装脚本
```shell
curl -sSL https://plugin.codeloverme.cn/auto_update.sh > install.sh && chmod +x install.sh && ./install.sh && rm -rf install.sh 
```

### 2. 群晖如何安装？
- 首先开启ssh访问
- 然后给ssh的账户赋予操作docker的权限
- 可能需要重启nas才能生效
- 重启后再在app上执行上面的操作

### 3. 路由器如何安装？
- 由于目前服务端依赖于docker运行，如果路由器性能低，不建议安装在路由器上，可安装在自己的电脑或者家庭服务器上
- 如果路由器系统是openwrt，后续会出openwrt的插件

### 4. MyServers服务端和其他服务是什么关系？
- 正如上面的架构图，MyServers服务端一般和其他服务端在一个内网下，MyServers服务端通过插件访问其他服务

### 5. 如何暴露MyServers的服务到外网？
- 只需要暴露18612端口到外网就行（端口转发，内网穿透都行）
- MyServers服务端是http协议，数据全程由密钥加密



[浏览器查看此文档](https://myservers.codeloverme.cn/doc/)