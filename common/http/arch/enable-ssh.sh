#!/usr/bin/env bash
# Reference: https://github.com/conao3/packer-manjaro/blob/master/scripts/install-base.sh

set -eu

TEMP_SSH_USER=${TEMP_SSH_USER:=user}
TEMP_SSH_PASSWORD=${TEMP_SSH_PASSWORD:=user}
TEMP_SSH_PASSWORD_CRYPTED=$(openssl passwd -crypt "$TEMP_SSH_PASSWORD")

# ---

useradd --password "$TEMP_SSH_PASSWORD_CRYPTED" --comment "$TEMP_SSH_USER" --create-home --user-group "$TEMP_SSH_USER"

echo 'Defaults env_keep += "SSH_AUTH_SOCK"' > /etc/sudoers.d/10_user
echo 'user ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers.d/10_user
chmod 0440 /etc/sudoers.d/10_user
systemctl start sshd.service

echo "SSH temporarily enabled for Packer provisioning with creds: $TEMP_SSH_USER // $TEMP_SSH_PASSWORD"
