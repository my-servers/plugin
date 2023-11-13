# frp Management

- Supports frp configuration file management
- Supports port probing

```yaml
extend:
  ConfigPath:
    val: "/nas/server/frpc/frpc.ini"
    desc: Configuration file
    priority: 200
  RestartScript:
    val: "docker restart frpc"
    desc: Restart script
    priority: 201
```

- `ConfigPath` The configuration file directory of frp
- `RestartScript` The restart script after the configuration update

