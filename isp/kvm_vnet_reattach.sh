#!/usr/bin/env bash

# if you run service network restart on vmmanager, all vnetX is not reattached
vnet=$( ip a | grep vnet* | awk '{print substr($2, 0, length($2)-1)}' )

ip link set dev $vnet master vmbr0
#or
#brctl addif vmbr0 $vnet
#ip link set $vnet up
