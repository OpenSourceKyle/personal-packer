#!/usr/bin/env bash

set -e 

PACKER_SSH_PRIV="common/ssh_keys_for_packer/id_rsa"

border () {
	echo "================================================================================"
}

# ---

clear
border

# Maintain proper file permissions for keys
chmod -v 600 "$PACKER_SSH_PRIV"
chown -Rv "$NEW_UID":"$NEW_GUID" .
border
