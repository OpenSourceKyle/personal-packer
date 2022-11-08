#!/usr/bin/env bash
#
# Temporarily enables SSH during a liveboot (for Packer)
#
# Reference: https://github.com/conao3/packer-manjaro/blob/master/srv/enable-ssh.sh

set -e
set -u
set -x

: "${TEMP_SSH_USER:=user}"
: "${TEMP_SSH_PASSWORD:=user}"

# --- Create temp user ---

useradd \
    --comment "$TEMP_SSH_USER" \
    --create-home \
    --user-group \
    "$TEMP_SSH_USER"

echo "${TEMP_SSH_USER}:${TEMP_SSH_PASSWORD}" | chpasswd \
    --crypt-method SHA512

echo -e 'Defaults env_keep += "SSH_AUTH_SOCK"\nuser ALL=(ALL) NOPASSWD: ALL' \
    > /etc/sudoers.d/10_user

chmod \
    0440 \
    /etc/sudoers.d/10_user

visudo \
    --check \
    --strict

systemctl start sshd.service

echo "SSH temporarily enabled for Packer provisioning with creds: $TEMP_SSH_USER // $TEMP_SSH_PASSWORD"
