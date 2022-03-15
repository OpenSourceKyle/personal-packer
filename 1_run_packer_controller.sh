#!/usr/bin/env bash

set -u

# Name used for tagging, hostname, etc.
export DOCKER_NAME="packer_controller"
# Outside, host folder to mount read-only from
export DOCKER_HOST_MOUNT="$(pwd)"
# Inside, container folder to mount read-only to
export DOCKER_CONTAINER_MOUNT="/root"

# ---

docker images rm "$DOCKER_NAME" 2>/dev/null

set -e

docker build \
	-t "$DOCKER_NAME" \
	-f Dockerfile \
	--build-arg UID="$(id -u)" \
        --build-arg GUID="$(id -g)" \
	. 
	# preserve this dot '.'

docker run \
	--hostname "$DOCKER_NAME" \
	--publish-all \
	--rm \
	--interactive=true \
	--tty=true \
	--volume "$DOCKER_HOST_MOUNT":"$DOCKER_CONTAINER_MOUNT/$DOCKER_NAME" \
	--volume "$HOME/.ssh":"$DOCKER_CONTAINER_MOUNT/.ssh":ro \
	--workdir="$DOCKER_CONTAINER_MOUNT/$DOCKER_NAME" \
	"$DOCKER_NAME"

