#!/usr/bin/env bash

set -e 

PACKER_SSH_PRIV="common/ssh_keys_for_packer/"

border () {
	echo "================================================================================"
}

# ---

clear
border

# Generate (if needed) and maintain proper file permissions for keys
if [[ ! -e "$PACKER_SSH_PRIV"/id_rsa ]] ; then
	echo "Keys not found... generating now!"
	ssh-keygen -f "$PACKER_SSH_PRIV"/id_rsa -P "" && cp -v id_rsa.pub authorized_keys
fi
chmod -v 600 "$PACKER_SSH_PRIV"
# chown -Rv "$NEW_UID":"$NEW_GUID" .
border
