#!/bin/bash

echo -e "准备安装服务端，安装完成前请不要关闭终端！"
# 检查Docker是否已经安装
docker_version=$(docker --version 2>/dev/null)
if [ $? -ne 0 ]; then
    echo "没有检测到docker，请先手动安装docker. curl -fsSL https://get.docker.com | sh"
    exit 1
fi

pid=`ps -ef | grep './myservers' | grep -v $$ | grep -v "auto_update.sh" | awk '{print $2}'`
if [ "$pid" != "" ]; then
  echo "检测到已启动的myservers进程${pid}，进行停止"
  kill -9 ${pid}
fi

app_dir=$2
image=$1

# 定义一个包含所有镜像的数组
images=("myservers/my_servers" "myservers/my_servers:dev" ${image})
# 循环遍历数组中的每个镜像
for image in "${images[@]}"; do
  # 查找使用该镜像的容器ID
  oldImg=$(docker ps -a --filter ancestor=${image} --format "{{.ID}}")
  # 如果找到了使用该镜像的容器
  if [ "$oldImg" != "" ]; then
    # 停止并删除容器
    docker stop ${oldImg}
    docker rm ${oldImg}
    # 输出删除镜像的信息
    echo "删除旧镜像：${image}"
    # 删除镜像
    docker image rm ${image}
  fi
done


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

if ! [ -d "$app_dir" ]; then
  mkdir $app_dir
  echo "创建安装目录: ${app_dir}"
fi

config_dir=$app_dir"/config"
if ! [ -d "$config_dir" ]; then
  mkdir $config_dir
  touch ${config_dir}"/config.yaml"
  echo "创建配置文件目录: ${config_dir}"
fi

data_dir=$app_dir"/data"
# 数据目录不存在，创建
if ! [ -d "$data_dir" ]; then
  mkdir $data_dir
  echo "创建数据目录: ${data_dir}"
fi

# 查看宿主机所有挂载的磁盘，需要挂载到容器，这样系统监控才会显示这些磁盘的信息
mounts=""
myServersAllDisk=""
while read -r dev path; do
  if [ "$path" = "/" ]; then
    continue
  fi
  if ! echo "$mounts" | grep -q "$dev"; then
    mounts="$mounts $dev $path"
    myServersAllDisk="$myServersAllDisk -v $path:$path "
  fi
done <<EOF
$(mount | grep "^/dev" | grep -v "boot" | grep -v "/etc/" | awk '{ print $1,$3 }')
EOF

cd ${app_dir}
docker run -it -d -v ~/.myservers/data:/app/data -v ~/.myservers/config:/app/config -v /proc:/proc -v /var/run:/var/run $myServersAllDisk --restart=always --net=host --name=myservers ${image} /app/app 2>&1 > /dev/null
docker exec -it myservers /app/app -op show_config