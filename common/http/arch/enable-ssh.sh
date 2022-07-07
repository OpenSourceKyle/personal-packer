#!/usr/bin/env bash

# Reference: https://github.com/conao3/packer-manjaro/blob/master/scripts/install-base.sh

PASSWORD=$(/usr/bin/openssl passwd -crypt 'user')

# user-specific configuration
/usr/bin/useradd --password ${PASSWORD} --comment 'User' --create-home --user-group user
echo 'Defaults env_keep += "SSH_AUTH_SOCK"' > /etc/sudoers.d/10_user
echo 'user ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers.d/10_user
/usr/bin/chmod 0440 /etc/sudoers.d/10_user
/usr/bin/systemctl start sshd.service
