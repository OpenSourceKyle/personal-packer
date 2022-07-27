#!/usr/bin/env bash
# Reference: https://github.com/conao3/packer-manjaro/blob/master/scripts/install-base.sh

set -eu

TEMP_SSH_USER=${TEMP_SSH_USER:-user}
TEMP_SSH_PASSWORD=${TEMP_SSH_PASSWORD:-user}

# ---

/usr/bin/useradd --password $(/usr/bin/openssl passwd -crypt "$TEMP_SSH_PASSWORD") --comment "$TEMP_SSH_USER" --create-home --user-group "$TEMP_SSH_USER"

/usr/bin/echo 'Defaults env_keep += "SSH_AUTH_SOCK"' > /etc/sudoers.d/10_user
/usr/bin/echo 'user ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers.d/10_user
/usr/bin/chmod 0440 /etc/sudoers.d/10_user
/usr/bin/systemctl start sshd.service

/usr/bin/echo "SSH temporarily enabled for Packer provisioning with creds: $TEMP_SSH_USER // $TEMP_SSH_PASSWORD"
