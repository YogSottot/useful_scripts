#!/usr/bin/env bash
set -eo pipefail

# fix this error in ispmanager
# spamd: still running as root: user not specified with -u, not found, or set to root, falling back to nobody
# plugin: eval failed: bayes: (in learn) locker: safe_lock: cannot create tmp lockfile /root/.spamassassin/bayes.lock. for /root/.spamassassin/bayes.lock: Permission denied

# create spamd user
useradd spamd --no-create-home --home-dir /etc/mail/spamassassin/ --shell /sbin/nologin

# set owner of home dir
chown spamd: -R /etc/mail/spamassassin/

# set tmpdir
echo "d /run/spamassassin/ 0755 spamd spamd" > /etc/tmpfiles.d/spamd.conf
systemd-tmpfiles --create

# set opts
#echo -e '# Options to spamd\nSPAMDOPTIONS="-c -m5 -H --razor-home-dir='/var/lib/razor/' --razor-log-file='sys-syslog'"' > /etc/sysconfig/spamassassin 
echo -e '# Options to spamd\nSPAMDOPTIONS="-c -m5 -H /etc/mail/spamassassin/ -u spamd -g spamd -x --virtual-config-dir=/etc/mail/spamassassin/"' > /etc/sysconfig/spamassassin

# apply changes
systemctl restart spamassassin.service

# example
# https://spamassassin.apache.org/full/3.1.x/doc/Mail_SpamAssassin_Conf.html
#cat /etc/mail/spamassassin/local.cf                        
# These values can be overridden by editing ~/.spamassassin/user_prefs.cf 
# (see spamassassin(1) for details)
                                                                           
# These should be safe assumptions and allow for simple visual sifting
# without risking lost emails.     
                                                                           
#required_score 7.0               
#report_safe 0                   
#rewrite_header Subject [SPAM]        
                                     
#ok_locales ru en uk             
#score UNWANTED_LANGUAGE_BODY 5.0
                                                                           
#score EMPTY_MESSAGE 5.0                                                    
                                     
#blacklist_from *@qq.com
