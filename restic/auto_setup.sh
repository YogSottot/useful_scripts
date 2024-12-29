#!/usr/bin/env bash
set -eo pipefail
# use
# curl -sL https://raw.githubusercontent.com/YogSottot/useful_scripts/master/restic/auto_setup.sh | bash -s -- rc_file relative_to_backup_root_site_dir your_mail hc_uuid
# curl -sL https://raw.githubusercontent.com/YogSottot/useful_scripts/master/restic/auto_setup.sh | bash -s -- www www mail@mail.tld uuid
mkdir -p /opt/backup/restic/{rc.files,exclude} && cd /opt/backup/
chmod 700 /opt/backup/
cd /opt/backup/restic/

# for mounting
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

$pkg_manager -y install bzip2 fuse s-nail jq

wget https://raw.githubusercontent.com/YogSottot/useful_scripts/master/restic/restic-wrapper.sh -N -P /opt/backup/restic/
wget https://raw.githubusercontent.com/YogSottot/useful_scripts/master/restic/restic-restore.sh -N -P /opt/backup/restic/
wget https://raw.githubusercontent.com/YogSottot/useful_scripts/master/restic/restic-diff.sh -N -P /opt/backup/restic/
wget https://raw.githubusercontent.com/YogSottot/useful_scripts/master/restic/www.rc  -N -P /opt/backup/restic/rc.files/
wget https://raw.githubusercontent.com/YogSottot/useful_scripts/master/restic/www.txt -N -P /opt/backup/restic/exclude/
chmod +x *.sh

wget https://github.com/restic/restic/releases/download/v0.13.1/restic_0.13.1_linux_amd64.bz2
bunzip2 restic_0.13.1_linux_amd64.bz2
mv restic_0.13.1_linux_amd64 /usr/local/bin/restic
chmod +x /usr/local/bin/restic
/usr/local/bin/restic self-update

/usr/local/bin/restic generate --bash-completion /etc/bash_completion.d/restic
source /etc/bash_completion.d/restic

#crontab -l | { cat; echo "30 1 * * *  /opt/backup/restic/restic-wrapper.sh $1 $3 --exclude-file=/opt/backup/restic/exclude/$1.txt backup $2 > /dev/null 2>&1 || true && /opt/backup/restic/restic-wrapper.sh $1 $3 forget --prune \${keep_policy[@]} > /dev/null 2>&1 || true"; } | crontab -
crontab -l | { cat; echo "30 1 * * * /usr/local/bin/restic self-update > /dev/null 2>&1 ;  /opt/backup/restic/restic-wrapper.sh $1 $3 $4 backup --iexclude-file=/opt/backup/restic/exclude/$1.txt $2 > /dev/null 2>&1 && /opt/backup/restic/restic-diff.sh $1 $3 $4 > /dev/null 2>&1 || true"; } | crontab -
crontab -l | { cat; echo "30 3 * * 7 /opt/backup/restic/restic-wrapper.sh $1 $3 $4 forget --prune --keep-daily 14 --keep-weekly 4 --keep-monthly 6 > /dev/null 2>&1 || true"; } | crontab -
crontab -l | { cat; echo "30 3 1 */2 * /opt/backup/restic/restic-wrapper.sh $1 $3 $4 check > /dev/null 2>&1 || true"; } | crontab -

echo 'do not forget to fill data in rc.file and init repo with > restic init'

# https://restic.readthedocs.io/en/latest/030_preparing_a_new_repo.html

# source restic/rc.files/www.rc
# restic init --repository-version 2
# https://restic.readthedocs.io/en/stable/045_working_with_repos.html#upgrading-the-repository-format-version
