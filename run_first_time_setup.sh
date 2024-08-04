#!/usr/bin/env bash

set -e 

PACKER_SSH_PRIV="common/ssh_keys_for_packer"

border () {
	echo "================================================================================"
}

# ---

clear
border

# Generate (if needed) and maintain proper file permissions for keys
if [[ ! -e "$PACKER_SSH_PRIV"/id_rsa ]] ; then
	echo "Keys not found... generating now!"
	border
	pushd "$PACKER_SSH_PRIV"
	ssh-keygen -f id_rsa -P "" && cp -v id_rsa.pub authorized_keys
	popd
else
	echo "Keys already exist in $PACKER_SSH_PRIV... *not* re-generating!"
fi
chmod -v 600 "$PACKER_SSH_PRIV"/id_rsa
border

packer plugins install github.com/hashicorp/virtualbox
packer plugins install github.com/hashicorp/qemu
