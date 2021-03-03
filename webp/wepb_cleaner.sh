#!/usr/bin/bash

# проверяем, если оригинальный jpg/png файл уже удалён, то удаляем и сконвертированный webp
/usr/bin/find /home/bitrix/www/upload/ -type f -name \*.webp | sed 's/\.webp$//'   | parallel  -ea 'out={}.webp; [ ! -f {} ] && rm "$out"'
