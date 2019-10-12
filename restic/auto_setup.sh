#!/bin/sh
set -e
# use
# curl -sL https://raw.githubusercontent.com/YogSottot/useful_scripts/master/restic/auto_setup.sh | bash -s -- rc_file relative_to_home_bitrix_site_dir your_mail

mkdir -p /opt/backup/restic/{rc.files,exclude} && cd /opt/backup/
chmod 700 /opt/backup/
cd /opt/backup/restic/

wget https://raw.githubusercontent.com/YogSottot/useful_scripts/master/restic/restic-wrapper.sh
wget https://raw.githubusercontent.com/YogSottot/useful_scripts/master/restic/www.rc  -N -P /opt/backup/restic/rc.files/
wget https://raw.githubusercontent.com/YogSottot/useful_scripts/master/restic/www.txt -N -P /opt/backup/restic/exclude/

wget https://github.com/restic/restic/releases/download/v0.9.5/restic_0.9.5_linux_amd64.bz2
bunzip2 restic_0.9.5_linux_amd64.bz2
mv restic_0.9.5_linux_amd64 /usr/local/bin/restic
chmod +x /usr/local/bin/restic
restic self-update

restic generate --bash-completion /etc/bash_completion.d/restic
source /etc/bash_completion.d/restic

#crontab -l | { cat; echo "30 1 * * * /opt/backup/restic/restic-wrapper.sh $1 $3 --exclude-file=/opt/backup/restic/exclude/$1.txt backup $2 > /dev/null 2>&1 || true && /opt/backup/restic/restic-wrapper.sh $1 $3 forget --prune \${keep_policy[@]} > /dev/null 2>&1 || true"; } | crontab -
crontab -l | { cat; echo "30 1 * * * /opt/backup/restic/restic-wrapper.sh $1 $3 backup --exclude-file=/opt/backup/restic/exclude/$1.txt $2 > /dev/null 2>&1 || true"; } | crontab -
crontab -l | { cat; echo "30 3 * * 7 /opt/backup/restic/restic-wrapper.sh $1 $3 forget --prune --keep-daily 14 --keep-weekly 4 --keep-monthly 2 > /dev/null 2>&1 || true"; } | crontab -
crontab -l | { cat; echo "30 3 1 */2 * /opt/backup/restic/restic-wrapper.sh $1 $3 check > /dev/null 2>&1 || true"; } | crontab -

echo 'do not forget to fill data in rc.file'
