# Yes, private keys being here are bad in theory

## However...

...these keys were generated for the sole purpose of uploading into Packer-built VMs, which will enable Ansible (when configured) to use these keys. This prevents having to use one's own keys or generating keys each time. If this is a concern, then delete these keys and copy or generate other ones into here. Or look into key storage servers and all the complexity that it would add to do that.

```shell
# Generate keys in current directory instead of the usual "~/.ssh",
# and assuming that the current directory is the location that the
# Packer build is set to use (which it is if this README.md is there)

ssh-keygen -f "$(pwd)"/id_rsa -P "" && cp -v id_rsa.pub authorized_keys
```
