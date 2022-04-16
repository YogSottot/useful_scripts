#!/bin/bash

# (main) Версия 21.1200.600 - долго выполняется запрос в бд

id=0
last=990000

while [ $id -le $last ]; do
    mysql --execute="use dev; delete o1 FROM b_user_access_check o1, b_user_access_check o2 WHERE o1.id > o2.id AND o1.USER_ID = o2.USER_ID AND o1.PROVIDER_ID = o2.PROVIDER_ID and o1.id < $id;"
    id=$[$id+10000];
    printf "Start $id\n"
done
