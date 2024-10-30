#!/usr/bin/env bash
set -x

# use
# bash <(curl -sL https://raw.githubusercontent.com/YogSottot/useful_scripts/master/isp/qemu_agent_fix.sh)

systemctl enable qemu-guest-agent || systemctl enable qemu-ga || \
chkconfig qemu-guest-agent on || chkconfig qemu-ga on

# Check existence of /etc/qemu/qemu-ga.conf
if qemu-ga -D && qemu-ga -D | grep -Pvq '(blacklist=$|block-rpcs=$)'; then

    QEMU_FOLDER='/etc/qemu/'
    if [ -d /etc/qemu-ga/ ]; then
        QEMU_FOLDER='/etc/qemu-ga/'
    fi

    if [ ! -f "${QEMU_FOLDER}qemu-ga.conf" ]; then
        touch "${QEMU_FOLDER}qemu-ga.conf"
        echo '[general]' > "${QEMU_FOLDER}qemu-ga.conf"
        echo 'blacklist=' >> "${QEMU_FOLDER}qemu-ga.conf"
        echo 'block-rpcs=' >> "${QEMU_FOLDER}qemu-ga.conf"
    else
        sed -i 's/^blacklist=.*/blacklist=/' "${QEMU_FOLDER}qemu-ga.conf"
        sed -i 's/^block-rpcs=.*/block-rpcs=/' "${QEMU_FOLDER}qemu-ga.conf"
    fi
fi

# Check existence of /etc/sysconfig/qemu-ga
if [ -f /etc/sysconfig/qemu-ga ]; then
    # Replace BLACKLIST_RPC line if found
    sed -i 's/^BLACKLIST_RPC=.*/BLACKLIST_RPC=/' /etc/sysconfig/qemu-ga
fi
