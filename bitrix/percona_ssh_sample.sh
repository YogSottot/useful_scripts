#!/usr/bin/env bash
database="$1"

printf "Start percona backup\n"
ssh spec.prod "/opt/backup/percona-db.sh"

printf "Start percona restore\n"
/opt/backup/percona-restore.sh

printf "Update db settings after restore\n"
/opt/backup/update_db.sh ${database}

printf "Remove managed_cache\n"
rm -rf /home/bitrix/www/bitrix/managed_cache/*

printf "Start rsync upload\n"
rsync -a spec.prod:/home/bitrix/www/upload/ /home/bitrix/www/upload/ --delete
printf "Rsync finished!\n"
