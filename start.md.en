# Quick Start

## Server Installation
First, install the server application. You can choose to install it using Docker or run it as a standalone process.

### Docker

#### One-Click Script Installation
```shell
curl -sSL https://plugin.codeloverme.cn/install.sh > install.sh && chmod +x install.sh && ./install.sh && rm -rf install.sh 
```

------------
> If the above method is installed successfully, ignore the "Manual Docker Installation".

#### Manual Docker Installation

1. **Host Machine**: Prepare a plugin directory. To prevent plugins from being lost after upgrading the server, it is recommended to store the plugins on the host machine and share them with the container through file directory mapping. Create a directory for the plugins on the host machine: `mkdir /xx/to/apps`.
2. **Host Machine**: Prepare the configuration file: `touch /xx/to/config.yaml` and `vim /xx/to/config.yaml`, with the following content:

```
RestConfig:
  Name: MyServers
  Host: 0.0.0.0
  Port: 18612
  Log:
    Stat: false
    Level: error
SecretKey: modify me (echo -n "test" | md5)
PluginUrl: https://plugin.codeloverme.cn/
MarkdownPage:
  About: https://plugin.codeloverme.cn/about.md
AppDir: apps
Name: codelover
```

- `SecretKey` is the secret key used for communication between the app and the server. it should be consistent between the app and the server, or they won't be able to communicate. You can generate it using `md5`:
  - `echo -n "test" | md5`
- `PluginUrl` is the URL for the plugin list, which contains all the downloadable plugins.
- `RestConfig.Port` is the port number.
- `AppDir` is the directory where the server scripts are saved.

3. Run the container and specify the parameters:
- Map the plugin directory: `-v /xx/to/apps:/apps`
- Map the configuration file (optional): `-v /xx/to/config.yaml:/app/config/config.yaml`
- Specify the plugin directory (if not specified, it will use the one in the configuration file): `-e AppDir=/apps`
- Specify the secret key (if not specified, it will use the one in the configuration file): `-e SecretKey=e8edf0cd4c5d49694c39edf7a879a92e`

```shell
docker run -it -d --network=host --name=myServers -v /xx/to/apps:/apps  -e AppDir=/apps -e SecretKey=e8edf0cd4c5d49694c39edf7a879a92e myservers/my_servers
```

4. Use the following command to login to the container and make modifications or view the container:
```shell
docker exec -it {id} sh
```

5. Restart the container after making modifications:
```shell
docker restart {id} 
```

### Server Upgrade
- Pull the latest server image and run it again:
```
# Pull the latest server image
docker pull myservers/my_servers
# Run it again
docker run -it -d --network=host --name=myServers -v /xx/to/apps:/apps  -e AppDir=/apps -e SecretKey=e8edf0cd4c5d49694c39edf7a879a92e myservers/my_servers
```


### Running the Server Process directly (to be completed)


## Client Installation

> The main operations of the client include **long press** and **click**.

### 1. Add a Server
- Go to the **Servers** page and **click** the `+` button to add a server.
- ![](https://myservers.codeloverme.cn/img/add_server.jpeg)
- Fill in the name (any name), IP and port, and the secret key (matching the server), then click `Submit`.
- Fill in the **necessary information**, then click to select.

### 2. Install Plugins to the Server
- Go to the **Apps** page
- ![](https://myservers.codeloverme.cn/img/add_plugin.png)
- **Long press** on the plugin you want to install and **click** `Enable`

### 3. Go to the Applications page
- **Long press** on the enabled application for `configuration`. Each plugin has different configurations. Click on the application for instructions.
- ![](https://myservers.codeloverme.cn/img/config_app.png)

For more features, please visit the [MyServers official website](https://myservers.codeloverme.cn).