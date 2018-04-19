#!/usr/bin/env bash

# use
# curl -sL https://raw.githubusercontent.com/YogSottot/useful_scripts/master/initial_server_setup/initial_setup.sh | bash

# mail
yum install cyrus-sasl-plain postfix -y

# postfix limits
mkdir -p /etc/systemd/system/postfix.service.d && echo -e '[Service]\nLimitNPROC=65535\nLimitNOFILE=100000'  >> /etc/systemd/system/postfix.service.d/override.conf && systemctl daemon-reload

cat <<EOT >> /etc/postfix/main.cf
#default_destination_concurrency_limit = 500
#default_destination_recipient_limit = 500
#initial_destination_concurrency = 50
#fork_delay = 1s
#in_flow_delay = 1s
#smtpd_recipient_limit = 30000
#mydestination =
#mynetworks_style = host
#fallback_transport = relay
# mydestination = localhost.$mydomain, localhost
EOT

systemctl enable postfix && systemctl restart postfix

cat <<EOT >> /etc/php.d/z_bx_custom.ini
sendmail_path = sendmail -t -i
EOT
