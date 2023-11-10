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

secret_key=$1
app_dir=$2
if [[ "$app_dir" == "" ]]; then
  app_dir=~/.myservers
fi

if [ -d "$app_dir" ]; then

else
    mkdir ~/.myservers
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
# 运行Docker容器（替换为你的Docker镜像名称和需要的环境变量）
docker run -d --network=host -v $app_dir:/apps -e AppDir=/apps -e SecretKey=$secret_key --name myServers --restart=always myservers/my_servers
# 输出运行状态
docker ps | grep myServers
echo -e "服务器程序已成功部署！"
echo "密钥：$secret_key"
echo "插件目录：$app_dir"
echo "端口：18612"