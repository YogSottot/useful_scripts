#!/usr/bin/env bash

# use
# bash <(curl -sL https://raw.githubusercontent.com/YogSottot/useful_scripts/master/initial_server_setup/postfix.sh)

# mail
yum install cyrus-sasl-plain postfix -y

# postfix limits
mkdir -p /etc/systemd/system/postfix.service.d && echo -e '[Service]\nLimitNPROC=65535\nLimitNOFILE=100000'  >> /etc/systemd/system/postfix.service.d/override.conf && systemctl daemon-reload

cat <<\EOT >> /etc/postfix/main.cf
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

echo "Do you wish to setup relay?"
select yn in "Yes" "No"; do
    case $yn in
        Yes )

cat <<EOT >> /etc/postfix/main.cf
#inet_protocols = ipv4
smtp_sasl_auth_enable = yes
smtp_sasl_password_maps = hash:/etc/postfix/mailpasswd
smtp_sasl_security_options = noanonymous
smtp_sasl_type = cyrus
smtp_sasl_mechanism_filter = login
smtp_sender_dependent_authentication = yes
header_size_limit = 4096000
smtp_use_tls = yes
sender_dependent_relayhost_maps = hash:/etc/postfix/sender_relay
sender_canonical_maps = hash:/etc/postfix/canonical
smtp_generic_maps = hash:/etc/postfix/generic
EOT

read -p "Please enter your relay. Example: smtp.yandex.ru: " relay
read -p "Please enter relay port. Example: 587: " port
read -p "Please enter mail login. Example: www@some.ru: " login
read -p "Please enter mail password: " password
read -p "Please enter mail domain. Example: some.ru: " domain

# указываем логин и пароль
cat <<EOT >> /etc/postfix/mailpasswd
[${relay}]:${port}      ${login}:${password}
EOT

# указываем привязку доменов и конкретных отправителей к внешним службам
cat <<EOT >> /etc/postfix/sender_relay
@${domain} [${relay}]:${port}
info@${domain} [${relay}]:${port}
EOT

# добавляем для домена указание через какой аккаунт отправлять
cat <<EOT >> /etc/postfix/canonical
@${domain}   info@${domain}
EOT

hostname=`/bin/hostname`

# добавляем отправку почты админу
cat <<EOT >> /etc/postfix/generic
root@${hostname} postmaster@${domain}
bitrix@${hostname} postmaster@${domain}
EOT

postmap /etc/postfix/generic
postmap /etc/postfix/canonical
postmap /etc/postfix/sender_relay
postmap /etc/postfix/mailpasswd

systemctl restart postfix
echo 'do not forget to systemctl reload httpd after testing' ; break;;
        No ) exit;;
    esac
done

# тестируем https://www.mail-tester.com/
# echo "Subject:My message" | sendmail -t -i mail@mail.com
# php -r "mail('your@mail.com', 'Test', 'Test');"
