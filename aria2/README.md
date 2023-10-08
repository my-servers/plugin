#  aria2 管理

## 先在服务端运行aria2

```shell
docker run -d \
--name aria2 \
--restart unless-stopped \
--log-opt max-size=1m \
-e PUID=$UID \
-e PGID=$GID \
-e UMASK_SET=022 \
-e RPC_SECRET=prc_password \
-e RPC_PORT=6800 \
-e LISTEN_PORT=6888 \
-p 16800:6800 \
-p 16888:6888 \
-p 16888:6888/udp \
-v /root/aria2/config:/config \
-v /root/aria2/downloads:/downloads \
p3terx/aria2-pro
```

- 可选`docker`运行，也可选其他方式，上面仅仅是一个`demo`
- 具体参数请参考`aria2`官方文档


## 配置
```yaml
name: aria2
enable: true
priority: 70
height: 6
padding: 3
extend:
  HostPort:
    val: "http://127.0.0.1:6800/jsonrpc"
    desc: 接口
    priority: 200
  Token:
    val: "prc_password"
    desc: 密钥
    priority: 200
```


-  `HostPort` aria2的管理地址
  - `http://127.0.0.1:6800/jsonrpc`
- `Token` 密钥，对应参数`RPC_SECRET`


## 功能
- 新增下载
- 管理下载任务
- 查看下载进度，详情等