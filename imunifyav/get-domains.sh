#!/bin/sh
jq -n '{ "data": { "default": { "document_root": "/home/bitrix/www/", "is_main": true, "owner": "bitrix" }, "dop": { "document_root": "/home/bitrix/ext_www/", "is_main": false, "owner": "bitrix" } }, "metadata": { "result": "ok" } }'
