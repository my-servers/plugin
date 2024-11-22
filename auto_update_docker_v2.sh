#!/bin/bash

echo -e "准备安装服务端，安装完成前请不要关闭终端！"
# 检查Docker是否已经安装
docker_version=$(docker --version 2>/dev/null)
if [ $? -ne 0 ]; then
    echo "没有检测到docker，请先手动安装docker. curl -fsSL https://get.docker.com | sh"
    exit 1
fi
ps aux | grep './myservers' | grep -v grep | awk '{print $2}' | xargs kill -9

app_dir=$2
image=$1

# 目录不存在就创建
if [ "$app_dir" == "" ]; then
  app_dir=~/.myservers
  echo "没有指定安装目录，使用默认目录：~/.myservers"
fi
echo "安装目录:${app_dir}"

if [ "$image" == "" ]; then
  image=myservers/my_servers
  echo "没有指定镜像，使用默认镜像：myservers/my_servers"
fi
echo "安装镜像：${image}"

app_dir=~/.myservers
if ! [ -d "$app_dir" ]; then
  mkdir $app_dir
  echo "创建安装目录: ${app_dir}"
fi
echo "创建docker-compose.yaml: ${app_dir}/docker-compose.yaml"
# 准备一个默认的配置文件
cat > ${app_dir}/docker-compose.yaml << EOF
services:
  myServers:
    # :dev是开发版，:latest是正式版
    image: ${image}
    # 主机网络接口
    network_mode: host
    container_name: myservers
    volumes:
      # 主机进程映射
      - /proc:/proc
      # docker等信息映射
      - /var/run:/var/run
      # 服务端所有的数据都在/app/data文件夹中，映射到主机 ~/.myservers/data，这样容器重建后数据不丢
      - ~/.myservers/data:/app/data
    # -k 密钥请自行修改
    command: /app/app -c /app/config/config.yaml
    restart: always
EOF

cd ${app_dir}
docker-compose up -d
docker logs -n 100 myservers