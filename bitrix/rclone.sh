#!/usr/bin/env bash

# error codes
# 0 - exited without problems
# 1 - parameters not supported were used or some unexpected error occured
# 2 - OS not supported by this script
# 3 - installed version of rclone is up to date
# 4 - supported unzip tools are not available

# use curl -sL https://raw.githubusercontent.com/YogSottot/useful_scripts/master/bitrix/rclone.sh | bash
set -e

#when adding a tool to the list make sure to also add it's corresponding command further in the script
unzip_tools_list=('unzip' '7z')

usage() { echo "Usage: curl https://rclone.org/install.sh | sudo bash [-s beta]" 1>&2; exit 1; }

#check for beta flag
if [ -n "$1" ] && [ "$1" != "beta" ]; then
    usage
fi

if [ -n "$1" ]; then
    install_beta="beta "
fi


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

#check installed version of rclone to determine if update is necessary
version=`rclone --version 2>>errors | head -n 1`
if [ -z "${install_beta}" ]; then
    current_version=`curl https://downloads.rclone.org/version.txt`
else
    current_version=`curl https://beta.rclone.org/version.txt`
fi

if [ "$version" = "$current_version" ]; then
    printf "\nThe latest ${install_beta}version of rclone ${version} is already installed.\n\n"
    exit 3
fi



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
if [ -z "${install_beta}" ]; then
    download_link="https://downloads.rclone.org/rclone-current-$OS-$OS_type.zip"
    rclone_zip="rclone-current-$OS-$OS_type.zip"
else
    download_link="https://beta.rclone.org/rclone-beta-latest-$OS-$OS_type.zip"
    rclone_zip="rclone-beta-latest-$OS-$OS_type.zip"
fi

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
    mkdir -p /root/.local/bin/
    cp rclone /root/.local/bin/rclone
    chmod 755 /root/.local/bin/rclone
    chown root:root /root/.local/bin/rclone
    mkdir -p /home/bitrix/.local/bin/
    cp rclone /home/bitrix/.local/bin/rclone
    chmod 755 /home/bitrix/.local/bin/rclone
    chown bitrix:bitrix /bitrix/.local/bin/rclone
    #manuals
    mkdir -p /usr/local/share/man/man1
    cp rclone.1 /usr/local/share/man/man1/
    mandb
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
printf '\nNow run "rclone config" for setup. Check https://rclone.org/docs/ for more details.\n\n'
exit 0
