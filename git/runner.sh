#!/usr/bin/env bash
set -e
# use
# curl -sL https://raw.githubusercontent.com/YogSottot/useful_scripts/master/git/runner.sh | bash

#curl -L https://packages.gitlab.com/install/repositories/runner/gitlab-runner/script.rpm.sh | bash
curl -L https://packages.gitlab.com/install/repositories/runner/gitlab-ci-multi-runner/script.rpm.sh | sudo bash
#yum -y install gitlab-runner
yum -y  gitlab-ci-multi-runner

# https://gitlab.com/gitlab-org/gitlab-runner/issues/2786
#/usr/share/gitlab-runner/post-install

mkdir /etc/systemd/system/gitlab-runner.service.d
echo -e '[Service]\nExecStart=\nExecStart=/usr/bin/gitlab-ci-multi-runner "run" "--working-directory" "/home/gitlab-runner" "--config" "/etc/gitlab-runner/config.toml" "--service" "gitlab-runner" "--syslog" "--user" "bitrix"'  >> /etc/systemd/system/gitlab-runner.service.d/override.conf
chown -R bitrix:bitrix /home/gitlab-runner/

systemctl daemon-reload
systemctl enable gitlab-runner
systemctl restart gitlab-runner

#gitlab-runner register
