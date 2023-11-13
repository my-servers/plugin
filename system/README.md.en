# system Management

> 🎉🎉🎉Added file management function, upgraded client and [server](https://myservers.codeloverme.cn/docs/intro#%E5%8D%87%E7%BA%A7%E6%9C%8D%E5%8A%A1%E7%AB%AF) experience, server version requires v1.1, client version requires v1.4

![](https://plugin.codeloverme.cn/system/file.png)


## Plugin Interface
![](https://plugin.codeloverme.cn/system/all.png)

## Plugin Configuration
- Hold down to display the interface
- ![](https://plugin.codeloverme.cn/system/config.png)
- `nas` Mount Point: You can map an external `nas` directory into the container, allowing you to monitor the storage usage of the `nas`. The default is the root directory.
  - For example, the above configuration maps the external nas file into the container's `/nas`, just configure this directory.
- Network Interface: Select the interface name on the machine to monitor upload and download speeds.
- CPU Trend Chart Size: Number of data points to retain in the current monitoring view.


## Features
- Monitor system performance
- Run shell commands
  - **Note: If running in a container, the command will be executed within the container**


-------------------

> The following content is the configuration file corresponding to the configuration interface above. You don't need to pay attention to it. You can modify it on the app without manually modifying it on the server.
## Configuration
```yaml
extend:
  CpuWin:
    val: "100"
    desc: Size of CPU trend chart window
    priority: 0
  Interface:
    val: eth0
    desc: Network interface
    priority: 90
  Disk:
    val: /
    desc: NAS mount point
    priority: 100

```