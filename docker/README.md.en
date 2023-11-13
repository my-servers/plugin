# Docker Management

## Plugin Interface
![](https://plugin.codeloverme.cn/docker/all.png)

## Plugin Configuration
- Long press the display interface
- ![](https://plugin.codeloverme.cn/docker/config.png)
- Docker service needs to enable the http port
  - Modify `/lib/systemd/system/docker.service` item `ExecStart` to add listening to `http`
  - Example: `ExecStart=/usr/bin/dockerd -H tcp://127.0.0.1:6666 -H fd:// --containerd=/run/containerd/containerd.sock`

## Features

### Images

- Search
- Pull
- Delete

### Containers
- **Long press** to bring up the menu
- ![](https://plugin.codeloverme.cn/docker/menu.jpg)
- **Click** to view details
- ![](https://plugin.codeloverme.cn/docker/detail.png)
- Start
- Run
- Stop

-------------------

> The following content is the configuration file corresponding to the above configuration interface. You don't need to worry about it. You can modify it on the App without manually modifying it on the server.

## Configuration

```yaml
HostPort:
  val: "http://127.0.0.1:6666"
  desc: Interface
  priority: 200
```