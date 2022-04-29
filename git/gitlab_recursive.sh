#!/usr/bin/env bash

cd /home/bitrix/www/
source /home/bitrix/.env/bin/activate

for i in `find . -mindepth 1 -maxdepth 1 -type d` ; do
cd /home/bitrix/www/$i && git pull && /home/bitrix/www/$i/manage.py migrate
done
