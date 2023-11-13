# Aria2 Management

## First, run aria2 on the server

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

- You can choose to run with `docker` or other methods, the above is just a `demo`
- For specific parameters, please refer to the official `aria2` documentation

## Configuration

```shell
name: aria2
enable: true
priority: 70
height: 6
padding: 3
extend:
HostPort:
val: "http://127.0.0.1:6800/jsonrpc"
desc: Interface
priority: 200
Token:
val: "prc_password"
desc: Secret key
priority: 200
```

- `HostPort` is the management address of aria2
    - `http://127.0.0.1:6800/jsonrpc`
- `Token` is the secret key, corresponding to the parameter `RPC_SECRET`

## Features
- Add new downloads
- Manage download tasks
- View download progress, details, etc.