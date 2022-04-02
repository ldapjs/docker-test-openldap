#!/bin/bash

set -e

d=$(date +'%Y-%m-%d')

docker build -t openldap .
docker tag openldap ghcr.io/ldapjs/docker-test-openldap/openldap:${d}
docker tag openldap ghcr.io/ldapjs/docker-test-openldap/openldap:latest
