#!/usr/bin/env bash
set -eo pipefail
# use
# bash <(curl -sL https://raw.githubusercontent.com/YogSottot/useful_scripts/master/initial_server_setup/postfix.sh)

# mail
# qshape deferred
yum install cyrus-sasl-plain postfix postfix-perl-scripts -y
alternatives --set mta /usr/sbin/sendmail.postfix
hostname=`/bin/hostname`
# postfix limits
mkdir -p /etc/systemd/system/postfix.service.d && echo -e '[Service]\nRestart=on-failure\nRestartSec=5\nLimitNPROC=65535\nLimitNOFILE=100000'  >> /etc/systemd/system/postfix.service.d/override.conf && systemctl daemon-reload

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
# для кривых корпоративных сеток, если не может правильно отрезолвить адрес внутреннего домена
# smtp_fallback_relay = [mail.domain.tld]:25
mailbox_size_limit = 0
message_size_limit = 0
virtual_mailbox_limit = 0
mydestination = localhost.$mydomain, localhost
virtual_alias_maps = hash:/etc/postfix/virtual
maximal_queue_lifetime = 1d
bounce_queue_lifetime = 5h
EOT

# добавляем отправку почты локальных пользователей
cat <<EOT >> /etc/postfix/virtual
root@${hostname} root@localhost
bitrix@${hostname} bitrix@localhost
EOT

postmap /etc/postfix/virtual

systemctl enable postfix && systemctl restart postfix

cat <<EOT >> /etc/php.d/z_bx_custom.ini
sendmail_path = /usr/sbin/sendmail -t -i 
EOT

echo "Do you wish to setup relay?"
select yn in "Yes" "No"; do
    case $yn in
        Yes )

cat <<EOT >> /etc/postfix/main.cf
inet_protocols = ipv4
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
${login} [${relay}]:${port}
EOT
#bitrix@${hostname} [${relay}]:${port}
#root@${hostname} [${relay}]:${port}


# добавляем для домена указание через какой аккаунт отправлять
cat <<EOT >> /etc/postfix/canonical
@${domain}   ${login}
EOT

hostname=`/bin/hostname`

# отключаем локальную доставку
find /etc/postfix/main.cf -type f -print0 | xargs -0 sed -i 's/mydestination\ \=\ \$myhostname\,\ localhost\.\$mydomain\,\ localhost/smydestination\ \=\ localhost\.\$mydomain\, localhost/g'

# добавляем отправку почты админу
#cat <<EOT >> /etc/postfix/generic
#root@${hostname} postmaster@${domain}
#bitrix@${hostname} postmaster@${domain}
#EOT



postmap /etc/postfix/generic
postmap /etc/postfix/canonical
postmap /etc/postfix/sender_relay
postmap /etc/postfix/mailpasswd

systemctl restart postfix
echo 'do not forget to systemctl reload httpd after testing' ; break;;
        No ) exit;;
    esac
done

echo "Do you use mail.ru as sender relay?"
           select yn in "Yes" "No"; do
               case $yn in
                  Yes )
# для mail.ru и их 550 error
cat <<EOT >> /etc/php.d/z_bx_custom.ini
sendmail_path = /usr/sbin/sendmail -t -i -f  ${login}
EOT
break;;
    No ) exit;;
esac
done

# https://serverfault.com/questions/147921/forcing-the-from-address-when-postfix-relays-over-smtp
# https://dev.1c-bitrix.ru/community/webdev/user/224396/blog/10266/
# тестируем https://www.mail-tester.com/
# echo "Subject:My message" | sendmail -t -i mail@mail.com
# php -r "mail('your@mail.com', 'Test', 'Test');"
# https://gist.github.com/zmwangx/2c56aa32be68daf48c2f
