#!/bin/bash

# Function to determine OS
detect_os() {
    case "$(uname -s)" in
        Linux*)     os=linux;;
        Darwin*)    os=darwin;;
        CYGWIN*)    os=windows;;
        MINGW*)     os=windows;;
        *)          os="unknown"
    esac
    echo $os
}

# Function to determine architecture
detect_arch() {
    case "$(uname -m)" in
        x86_64)     arch=amd64;;
        arm64)      arch=arm64;;
        aarch64)    arch=arm64;;
        arm*)       arch=arm;;
        i386)       arch=386;;
        i686)       arch=386;;
        *)          arch="unknown"
    esac
    echo $arch
}

# Function to determine ARM version (if applicable)
detect_arm_version() {
    if [ "$(detect_arch)" = "arm" ]; then
        # This is a simplistic way to determine ARM version, may need more robust handling
        arm_version=$(uname -m | sed 's/armv\(.*\)\(.*\)/\1/')
        echo $arm_version
    else
        echo ""
    fi
}

download_myservers() {
  os=$(detect_os)
  arch=$(detect_arch)
  arm_version=$(detect_arm_version)

  if [ "$arm_version" != "" ]; then
      filename="${serverName}-${os}-${arch}${arm_version}"
  else
      filename="${serverName}-${os}-${arch}"
  fi
  base_url="http://qiniuyun.codeloverme.cn"

  # Full URL to the binary
  url="${base_url}/${filename}"

  # Download the binary
  appName="${app_dir}/myservers"
  echo "下载中，请不要关闭终端... $appName from $url"
  curl  --progress-bar -o "$appName" "$url"
  chmod +x $appName
}

# Main script starts here
serverName=$1
app_dir=$2

if [ "$app_dir" == "" ]; then
  app_dir=~/.myservers
  echo "没有指定安装目录，使用默认目录：~/.myservers"
fi
echo "安装目录:${app_dir}"

if [ "$serverName" == "" ]; then
  serverName="myservers"
fi

app_dir=~/.myservers
if ! [ -d "$app_dir" ]; then
  mkdir $app_dir
  echo "创建安装目录: ${app_dir}"
fi

oldImg=`docker ps -a --filter ancestor=myservers/my_servers --format "{{.ID}}"`
if [ "$oldImg" != "" ]; then
  docker stop ${oldImg}
  docker rm ${oldImg}
fi

oldImg=`docker ps -a --filter ancestor=myservers/my_servers:dev --format "{{.ID}}"`
if [ "$oldImg" != "" ]; then
  docker stop ${oldImg}
  docker rm ${oldImg}
fi

ps aux | grep './myservers' | grep -v grep | awk '{print $2}' | xargs kill -9
download_myservers

cd ${app_dir}
./myservers > /dev/null &
./myservers -op show_config