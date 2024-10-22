#!/usr/bin/env bash
set -e
# error codes
# 0 - exited without problems
# 1 - parameters not supported were used or some unexpected error occured
# 2 - OS not supported by this script
# 3 - installed version of rclone is up to date
# 4 - supported unzip tools are not available

# use curl -sL https://raw.githubusercontent.com/YogSottot/useful_scripts/master/bitrix/rclone.sh | bash -s -- /home/bitrix/www
set -e

#when adding a tool to the list make sure to also add it's corresponding command further in the script
unzip_tools_list=('unzip' '7z')

#create tmp directory and move to it with macOS compatibility fallback
tmp_dir=`mktemp -d 2>/dev/null || mktemp -d -t 'rclone-install'`; cd $tmp_dir

#make sure unzip tool is available and choose one to work with
set +e
    yum install unzip -y


for tool in ${unzip_tools_list[*]}; do
    trash=`hash $tool 2>>errors`
    if [ "$?" -eq 0 ]; then
        unzip_tool="$tool"
        break
    fi
done  
set -e

# Make sure we don't create a root owned .config/rclone directory #2127
export XDG_CONFIG_HOME=config

#detect the platform
OS="`uname`"
case $OS in
  Linux)
    OS='linux'
    ;;
  FreeBSD)
    OS='freebsd'
    ;;
  NetBSD)
    OS='netbsd'
    ;;
  OpenBSD)
    OS='openbsd'
    ;;  
  Darwin)
    OS='osx'
    ;;
  SunOS)
    OS='solaris'
    echo 'OS not supported'
    exit 2
    ;;
  *)
    echo 'OS not supported'
    exit 2
    ;;
esac

OS_type="`uname -m`"
case $OS_type in
  x86_64|amd64)
    OS_type='amd64'
    ;;
  i?86|x86)
    OS_type='386'
    ;;
  arm*)
    OS_type='arm'
    ;;
  *)
    echo 'OS type not supported'
    exit 2
    ;;
esac


#download and unzip
    download_link="https://downloads.rclone.org/rclone-current-$OS-$OS_type.zip"
    rclone_zip="rclone-current-$OS-$OS_type.zip"

curl -O $download_link
unzip_dir="tmp_unzip_dir_for_rclone"
# there should be an entry in this switch for each element of unzip_tools_list
case $unzip_tool in
  'unzip')
    unzip -a $rclone_zip -d $unzip_dir
    ;;
  '7z')
    7z x $rclone_zip -o$unzip_dir
    ;;
esac
    
cd $unzip_dir/*


#mounting rclone to enviroment

case $OS in
  'linux')
    #binary
    mv rclone /usr/local/bin/rclone
    chmod 755 /usr/local/bin/rclone
    chown root:root /usr/local/bin/rclone
    ;;
  'freebsd'|'openbsd'|'netbsd')
    #bin
    cp rclone /usr/bin/rclone.new
    chown root:wheel /usr/bin/rclone.new
    mv /usr/bin/rclone.new /usr/bin/rclone
    #man
    mkdir -p /usr/local/man/man1
    cp rclone.1 /usr/local/man/man1/
    makewhatis
    ;;
  'osx')
    #binary
    mkdir -p /usr/local/bin
    cp rclone /usr/local/bin/rclone.new
    mv /usr/local/bin/rclone.new /usr/local/bin/rclone
    #manual
    mkdir -p /usr/local/share/man/man1
    cp rclone.1 /usr/local/share/man/man1/    
    ;;
  *)
    echo 'OS not supported'
    exit 2
esac


#update version variable post install
version=`rclone --version 2>>errors | head -n 1`

printf "\n${version} has successfully installed."

cat <<EOT >> /opt/backup/scripts/rclone.conf
[selectel_s3]
type = s3
provider = Other
access_key_id = 
secret_access_key = 
region = ru-1
endpoint = s3.ru-1.storage.selcloud.ru
EOT

chmod 600 /opt/backup/scripts/rclone.conf



exit 0
