#!/bin/bash

blue_bg="\033[44m"
reset_color="\033[0m"

if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS系统
    blue_bg=$(tput setab 4)
    reset_color=$(tput sgr0)
fi

# 收集用户参数
echo -e "${blue_bg}请输入密钥（长度32，不足的会根据输入算出md5作为密钥）: ${reset_color}"
read secret_key
echo -e "${blue_bg}请输入插件保存的目录（宿主机目录）:  ${reset_color}"
read app_dir


# 检查Docker是否已经安装
if ! command -v docker &> /dev/null; then
    echo "Docker未安装，开始安装Docker..."
    # 安装Docker
    curl -fsSL https://get.docker.com | bash
else
    echo "Docker已安装，跳过安装步骤。"
fi
cat << "EOF"
 ____    ____             ______
|_   \  /   _|          .' ____ \
  |   \/   |    _   __  | (___ \_| .---.  _ .--.  _   __  .---.  _ .--.  .--.
  | |\  /| |   [ \ [  ]  _.____`. / /__\\[ `/'`\][ \ [  ]/ /__\\[ `/'`\]( (`\]
 _| |_\/_| |_   \ '/ /  | \____) || \__., | |     \ \/ / | \__., | |     `'.'.
|_____||_____|[\_:  /    \______.' '.__.'[___]     \__/   '.__.'[___]   [\__) )
               \__.'
EOF


# 检查密钥长度是否为32
if [ ${#secret_key} -ne 32 ]; then
    echo "密钥长度不足32，将根据输入计算md5作为密钥。"
    # 判断系统类型，选择合适的md5命令
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS系统
        secret_key=$(echo -n "$secret_key" | md5)
    else
        # 其他系统，如Linux
        secret_key=$(echo -n "$secret_key" | md5sum | awk '{print $1}')
    fi
else
    echo "密钥长度满足32。"
fi

while true; do
    # 检查输入的是否是目录
    if [ -d "$app_dir" ]; then
        echo "有效的目录: $app_dir"
        break
    else
        echo "无效的目录，请重新输入。"
        read -p "${blue_bg}请输入插件保存的目录（宿主机目录）:${reset_color} " app_dir
    fi
done


# 拉取Docker镜像（替换为你的Docker镜像名称）
docker pull myservers/my_servers

# 运行Docker容器（替换为你的Docker镜像名称和需要的环境变量）
docker run -d --network=host -v $app_dir:/apps -e AppDir=/apps -e SecretKey=$secret_key --name myServers myservers/my_servers

# 输出运行状态
docker ps | grep myServers

echo -e "\n\n服务器程序已成功部署！\n${blue_bg}密钥：${reset_color}$secret_key \n${blue_bg}插件目录：${reset_color}$app_dir \n${blue_bg}默认端口：${reset_color}18612"