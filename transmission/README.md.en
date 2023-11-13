# transmission Management

## First, run transmission on the server

```shell
docker run -d \
  --name=transmission \
  -e PUID=1000 \
  -e PGID=1000 \
  -e TZ=Shanghai/China \
  -e TRANSMISSION_WEB_HOME=/transmission-web-control/ \
  -e USER=username \
  -e PASS=password \
  -p 9091:9091 \
  -p 51413:51413 \
  -p 51413:51413/udp \
  -v /root/transmission/config:/config \
  -v /root/transmission/downloads:/downloads \
  -v /root/transmission/watch:/watch \
  --restart unless-stopped \
  linuxserver/transmission
```
- Configure the login username and password
- For specific configuration, please refer to the official documentation of transmission



## Configuration

```yaml
  HostPort:
    val: http://username:password@127.0.0.1:9091
    desc: IP and port (including username and password)
    priority: 180
  DownloadPath:
    val: /downloads
    desc: Download path
    priority: 170
```

- `HostPort` Username, password, and IP address
  - `http://username:password@127.0.0.1:9091`


## Features
- Add new downloads
- Manage download tasks
- View download progress, details, etc.