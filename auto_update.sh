#!/bin/sh

# 随机密钥生成
generate_random_string() {
  length="${1:-32}"
  charset="abcdefghijklmnopqrstuvwxyz0123456789"
  result=""
  i=0
  while [ $i -lt $length ]; do
    rand_index=$(( RANDOM % ${#charset} ))
    result="${result}${charset:$rand_index:1}"
    i=$((i+1))
  done

  echo "$result"
}

echo -e "准备安装服务端，安装完成前请不要关闭终端！"

# 检查Docker是否已经安装
docker_version=$(docker --version 2>/dev/null)
if [ $? -ne 0 ]; then
    echo "没有检测到docker，请先手动安装docker. curl -fsSL https://get.docker.com | sh"
    exit 1
fi

# 删除旧的镜像，升级的时候会用到这个逻辑
oldImg=`docker ps -a --filter ancestor=myservers/my_servers --format "{{.ID}}"`
if [ "$oldImg" != "" ]; then
  docker stop ${oldImg}
  docker rm ${oldImg}
fi
docker image rm myservers/my_servers

# 参数 密钥 插件下载目录
secret_key=$1
app_dir=$2

# 目录不存在就创建
if [ "$app_dir" == "" ]; then
  app_dir=~/.myservers
fi
if ! [ -d "$app_dir" ]; then
  mkdir $app_dir
fi

# 迁移下老数据，大概率不会用到了
apps_dir=$app_dir"/app"
if ! [ -d "$apps_dir" ]; then
  mkdir -p $apps_dir
  for item in ${app_dir}/*; do
  if [ "${item}" != "$apps_dir" ]; then
    mv "${item}" "${apps_dir}/"
  fi
done
fi

# 删除下依赖的基本库，服务端启动的时候没有会自动下载最新的
rm -rf ${apps_dir}/tool.lua
rm -rf ${apps_dir}/ctx.lua

# 准备一个默认的配置文件
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
    secret_key=$(generate_random_string 32)
fi

# 查看宿主机所有挂载的磁盘，需要挂载到容器，这样系统监控才会显示这些磁盘的信息
mounts=""
allMount=$(mount | grep "^/dev" | grep -v "boot" | awk '{ print $1,$3 }')
myServersAllDisk=""
while read -r dev path; do
  if [ "$path" = "/" ]; then
    continue
  fi
  if ! echo "$mounts" | grep -q "$dev"; then
    mounts="$mounts $dev $path"
    myServersAllDisk="$myServersAllDisk -v $path:/hostDisk$path "
  fi
done <<EOF
$(mount | grep "^/dev" | awk '{ print $1,$3 }')
EOF

# 拉取Docker镜像（替换为你的Docker镜像名称）
docker pull myservers/my_servers
# # 运行Docker容器（替换为你的Docker镜像名称和需要的环境变量）
docker run -d --network=host -v ${apps_dir}:/app/apps -v ${config_dir}:/app/config $myServersAllDisk --name myServers --restart=always myservers/my_servers /app/app -k $secret_key -c /app/config/config.yaml

# 检查是否正常启动
hasServer=`docker ps --filter ancestor=myservers/my_servers --format "{{.ID}}"`
if [ "$hasServer" == "" ]; then
  echo "安装似乎出现了问题，可以手动执行：docker run -d --network=host -v ${apps_dir}:/app/apps -v ${config_dir}:/app/config $myServersAllDisk --name myServers --restart=always myservers/my_servers /app/app -k $secret_key -c /app/config/config.yaml"
  exit 0
fi

#clear
docker ps | grep myServers
echo -e "服务器程序已成功升级！"
echo "本次运行脚本：docker run -d --network=host -v ${apps_dir}:/app/apps -v ${config_dir}:/app/config $myServersAllDisk --name myServers --restart=always myservers/my_servers /app/app -k $secret_key -c /app/config/config.yaml"
echo "密钥: $secret_key"
echo "插件目录: $apps_dir"
echo "配置文件目录: $config_dir"
echo "端口: 18612"