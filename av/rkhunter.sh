#!/usr/bin/env bash
set -eo pipefail

# use
# curl -sL https://raw.githubusercontent.com/YogSottot/useful_scripts/master/av/rkhunter.sh | bash -s -- your_mail

# Get OS and version information

mail=$1

if [ -z ${mail} ]; then
    echo "Enter your email address to receive reports"
	echo Usage: $0 mail@domain.tld 
	exit
fi

get_pkg_manager() {
    local os_info; os_info=$(grep "^ID=" /etc/os-release | cut -d= -f2 | tr -d '"')

    if [[ "$os_info" == "debian" || "$os_info" == "ubuntu" ]]; then
        pkg_manager="apt"
    elif [[ "$os_info" == "rhel" || "$os_info" == "almalinux" || "$os_info" == "rocky" || "$os_info" == "centos" || "$os_info" == "oracle" ]]; then
        pkg_manager="dnf"
    else
        printf "OS not supported!\n" >&2
        return 1
    fi
}

main() {
    if ! get_pkg_manager; then
        exit 1
    fi
    printf "Package manager: %s\n" "$pkg_manager"
}

main "$@"



$pkg_manager -y install rkhunter inotify-tools unhide s-nail unzip

# generate db
rkhunter --update
rkhunter --propupd


find /etc/sysconfig/rkhunter -type f -print0 | xargs -0 sed -i 's/MAILTO\=root\@localhost/MAILTO\='${mail}'/g'
echo 'ALLOWHIDDENDIR=/etc/.hg' >> /etc/rkhunter.conf.local
echo 'ALLOWHIDDENFILE=/etc/.hgignore' >> /etc/rkhunter.conf.local
echo 'ALLOWHIDDENDIR=/dev/shm/byobu-*/.last.tmux' >> /etc/rkhunter.conf.local
echo 'ALLOWDEVFILE=/dev/shm/byobu-*-????????/.last.tmux/*' >> /etc/rkhunter.conf.local
echo 'ALLOWDEVFILE=/dev/shm/byobu-*-????????/*/*' >> /etc/rkhunter.conf.local
echo 'ALLOWDEVFILE=/dev/shm/byobu-*-????????/*' >> /etc/rkhunter.conf.local
