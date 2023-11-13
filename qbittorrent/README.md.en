# qbittorrent Management


## First, run qbittorrent on the server

```shell
docker run -d \
  --name=qbittorrent \
  -p 7881:7881 \
  -p 7881:7881/udp \
  -p 18080:18080 \
  -v /data/qbittorrent/config:/etc/qBittorrent \
  -v /data/qbittorrent/downloads:/downloads \
  --restart unless-stopped \
  helloz/qbittorrent
```
- Configure the login username and password
- For specific configuration, please refer to the official documentation of qbittorrent

------------

## Plugin Interface

![](https://plugin.codeloverme.cn/qbittorrent/all.png)


## Plugin Configuration

- Hold down to display the interface
- ![](https://plugin.codeloverme.cn/qbittorrent/config.png)
- Fill in the information based on the backend server configuration, focusing on username, password, IP, and port



## Features
- Add new downloads (add magnet links)
- Manage download tasks, long press on each task to bring up the menu
- ![](https://plugin.codeloverme.cn/qbittorrent/menu.jpg)
- View download progress, details, etc. Click on a task to view details
- ![](https://plugin.codeloverme.cn/qbittorrent/detail.png)
- Search for downloads
  - Requires installation of search plugin on the server


-------------------

> The following content is the configuration file corresponding to the configuration interface above. You don't need to pay attention to it. You can modify it on the app without manually modifying it on the server.
## Configuration File

```yaml
name: qBittorrent
enable: true
priority: 90
height: 6
padding: 3
extend:
  ColNum:
    val: "2"
    desc: Number of columns to display
    priority: 200
  NameLen:
    val: "20"
    desc: Name length limit
    priority: 210
  Username:
    val: username
    desc: Username
    priority: 200
  Password:
    val: password
    desc: Password
    priority: 190
  HostPort:
    val: http://127.0.0.1:18080
    desc: IP and port
    priority: 180
  SearchNum:
    val: "20"
    desc: Number of search results to display
    priority: 170
```

- `HostPort` IP and port
  - `http://127.0.0.1:18080`
- `Username` The username set above
- `Password` The password set above