#!/usr/bin/env bash

regex="max_client_conn|Error"

journalctl -f -n 0 -u uwsgi.service |
while read line
do
    if [[ "$line" =~ $regex ]]; then
        sleep 15 && systemctl restart uwsgi.service
    fi
done
