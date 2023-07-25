#!/bin/bash

set -e

d=$(date +'%Y-%m-%d')


BUILDER='ldapjs-builder'
PLATFORMS='linux/amd64,linux/arm64'

# https://stackoverflow.com/a/49627999/7979
HAS_BUILDER=$(docker buildx ls | { grep -e '^ldapjs-builder' || test $? = 1; } )
if [ -z "${HAS_BUILDER}" ]; then
  docker buildx create \
    --driver docker-container \
    --platform ${PLATFORMS} \
    --name ${BUILDER}
fi

docker buildx build \
  --platform ${PLATFORMS} \
  --builder ${BUILDER} \
  --output type=image \
  --push \
  -t ghcr.io/ldapjs/docker-test-openldap/openldap:${d} \
  .

docker buildx build \
  --platform ${PLATFORMS} \
  --builder ${BUILDER} \
  --output type=image \
  --push \
  -t ghcr.io/ldapjs/docker-test-openldap/openldap:latest \
  .