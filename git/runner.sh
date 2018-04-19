#!/usr/bin/env bash

# use
# curl -sL https://raw.githubusercontent.com/YogSottot/useful_scripts/master/git/runner.sh | bash

curl -L https://packages.gitlab.com/install/repositories/runner/gitlab-ci-multi-runner/script.rpm.sh | bash
yum -y install gitlab-ci-multi-runner

mkdir /etc/systemd/system/gitlab-runner.service.d
echo -e '[Service]\nExecStart=\nExecStart=/usr/bin/gitlab-ci-multi-runner "run" "--working-directory" "/home/gitlab-runner" "--config" "/etc/gitlab-runner/config.toml" "--service" "gitlab-runner" "--syslog" "--user" "bitrix"'  >> /etc/systemd/system/gitlab-runner.service.d/override.conf
chown -R bitrix:bitrix /home/gitlab-runner/

systemctl daemon-reload
systemctl restart gitlab-runner

#gitlab-runner register
