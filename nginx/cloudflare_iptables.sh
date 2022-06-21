#!/usr/bin/env bash

#ipset create cloudflare-v4 hash:net family inet
#ipset create cloudflare-v6 hash:net family inet6

#iptables -I INPUT -p tcp -m set --match-set cloudflare-v4 src -m multiports --dports 80,443 -j ACCEPT
#ip6tables -I INPUT -p tcp -m set --match-set cloudflare-v6 src -m multiports --dports 80,443 -j ACCEPT

#while read ip ; do ipset -A cloudfare-v4 "$ip" ; done <<< "$(curl https://www.cloudflare.com/ips-v4)"
#while read ip ; do ipset -A cloudfare-v6 "$ip" ; done <<< "$(curl https://www.cloudflare.com/ips-v6)"

# name of the ipset - v4 or v6 will be appended.
IPSET_NAME=cloudflare-

# argument: v4 or v6 (defaults to v4)
cloudflare_ipset ()
{
        local ipv
        local inetv

        if [ -z "$1" ]; then ipv="v4"; else ipv="$1"; fi

        if [ "$ipv" = "v4" ]
                then inetv="inet"
                else inetv="inet6"
        fi

        IPSET_NAME="$IPSET_NAME$ipv"

        local content_re='^[0-9a-f:.\r\n/ ]+$'

        local url="https://www.cloudflare.com/ips-$ipv/"
        local ipdata; # local is a command that affects $?, so must be separate!
        ipdata=$(curl --fail -L "$url" 2>/dev/null | tr -s "[:space:]" " ")
        local ret=$?

        if [ $ret -eq 0 ] && [[ $ipdata =~ $content_re ]]; then
                if ipset list $IPSET_NAME 2>/dev/null 1>/dev/null
                then
                        echo "Updating $IPSET_NAME set..."
                        ipset flush $IPSET_NAME
                else
                        echo "Creating $IPSET_NAME set..."
                        ipset create $IPSET_NAME hash:net family $inetv
                fi
                for i in $ipdata
                do
                        ipset add $IPSET_NAME $i
                done

                local count=`ipset list $IPSET_NAME | wc -l`
                count=$((count-7))
                echo "Set $IPSET_NAME now has $count entries."
                return 0
        else
                echo "Download failed, sets not modified."
                return 1
        fi
}

cloudflare_ipset "$1"

exit $?


#for i in `curl https://www.cloudflare.com/ips-v4`; do iptables -I INPUT -p tcp -m multiport --dports http,https -s $i -j ACCEPT; done
#for i in `curl https://www.cloudflare.com/ips-v6`; do ip6tables -I INPUT -p tcp -m multiport --dports http,https -s $i -j ACCEPT; done

# Avoid racking up billing/attacks
# WARNING: If you get attacked and CloudFlare drops you, your site(s) will be unreachable. 
#iptables -A INPUT -p tcp -m multiport --dports http,https -j DROP
#ip6tables -A INPUT -p tcp -m multiport --dports http,https -j DROP
