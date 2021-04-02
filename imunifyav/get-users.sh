#!/bin/sh
# https://docs.imunifyav.com/stand_alone_mode/#integration-config-file
jq -n '{  "data": [{"id": 600, "username":  "bitrix" }  ],  "metadata": {  "result": "ok"  } }'
# jq -n '{  "data": [{"id": 600, "username":  "bitrix", "owner": "root", "domain": "ins5yo3.com", "package": { "name": "bitrix", "owner": "root" },      "email": "ins5yo3@ins5yo3.com", "locale_code": "EN_us" }  ],  "metadata": {  "result": "ok"  } }'
