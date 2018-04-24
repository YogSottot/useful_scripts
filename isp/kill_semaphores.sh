#!/usr/bin/env bash

# use
# curl -sL https://raw.githubusercontent.com/YogSottot/useful_scripts/master/isp/kill_semaphores.sh | bash -s -- user

PATH="/bin:/usr/bin"
USER=$1

ipcs
read -p "press enter to kill all the ipc process owned by ${USER}"

IPCS_S=$(ipcs -s | egrep "0x[0-9a-f]+ [0-9]+" | grep ${USER} | cut -f2 -d" ")
IPCS_M=$(ipcs -m | egrep "0x[0-9a-f]+ [0-9]+" | grep ${USER} | cut -f2 -d" ")
IPCS_Q=$(ipcs -q | egrep "0x[0-9a-f]+ [0-9]+" | grep ${USER} | cut -f2 -d" ")

for id in ${IPCS_M}; do
  ipcrm -m ${id};
done

for id in $IPCS_S; do
  ipcrm -s ${id};
done

for id in $IPCS_Q; do
  ipcrm -q ${id};
done
