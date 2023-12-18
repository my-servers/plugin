#!/bin/sh
# 检查Docker是否已经安装
if ! command -v docker &> /dev/null; then
    echo "Docker未安装，开始安装Docker..."
    # 安装Docker
    curl -fsSL https://get.docker.com | sh
else
    echo "Docker已安装，跳过安装步骤。"
fi
clear

docker ps -a --filter ancestor=myservers/my_servers --format "{{.ID}}"|xargs docker stop |xargs docker rm
docker image rm myservers/my_servers
secret_key=$1
app_dir=$2
if [[ "$app_dir" == "" ]]; then
  app_dir=~/.myservers
fi

if ! [ -d "$app_dir" ]; then
  mkdir $app_dir
fi

apps_dir=$app_dir"/app"
if ! [ -d "$apps_dir" ]; then
  mkdir -p $apps_dir
  for item in ${app_dir}/*; do
  if [ "${item}" != "$apps_dir" ]; then
    mv "${item}" "${apps_dir}/"
  fi
done
fi

rm -rf ${apps_dir}/tool.lua
rm -rf ${apps_dir}/ctx.lua

config_dir=$app_dir"/config"
if ! [ -d "$config_dir" ]; then
  mkdir $config_dir
  cat > ${config_dir}"/config.yaml" << "EOF"
RestConfig:
  Name: MyServers
  Host: 0.0.0.0
  Port: 18612
  Log:
    Stat: false
    Level: error
SecretKey: e8edf0cd4c5d49694c39edf7a879a92e
PluginUrl: https://plugin.codeloverme.cn/
MarkdownPage:
  About: https://plugin.codeloverme.cn/about.md
AppDir: /app/apps
Name: MyServers
EOF
fi
# 检查密钥长度是否为32
if [ ${#secret_key} -ne 32 ]; then
    # 判断系统类型，选择合适的md5命令
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS系统
        secret_key=$(echo -n "$secret_key" | md5)
    else
        # 其他系统，如Linux
        secret_key=$(echo -n "$secret_key" | md5sum | awk '{print $1}')
    fi
fi

# 拉取Docker镜像（替换为你的Docker镜像名称）
docker pull myservers/my_servers
# # 运行Docker容器（替换为你的Docker镜像名称和需要的环境变量）
docker run -d --network=host -v ${apps_dir}:/app/apps -v ${config_dir}:/app/config --name myServers --restart=always myservers/my_servers /app/app -k $secret_key -c /app/config/config.yaml
# 输出运行状态

#clear
docker ps | grep myServers
echo -e "服务器程序已成功升级！"
echo "密钥: $secret_key"
echo "插件目录: $apps_dir"
echo "配置文件目录: $config_dir"
echo "端口: 18612"