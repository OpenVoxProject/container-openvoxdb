#!/usr/bin/env bash

set -e

if command -v apk > /dev/null 2>&1; then
  apk update
  apk add --no-cache \
    curl \
    dumb-init \
    runuser \
    coreutils \
    gcompat
elif command -v apt-get > /dev/null 2>&1; then
  apt-get update
  apt-get install -y --no-install-recommends \
    coreutils \
    curl \
    dumb-init \
    util-linux
  apt-get clean
  rm -rf /var/lib/apt/lists/*
else
  echo "Unsupported package manager" >&2
  exit 1
fi

# Create puppet user and group, and set permissions on necessary directories
# Used for rootless execution of the container and to match permissions expected by Puppet Server
if command -v apk > /dev/null 2>&1; then
  addgroup -g 64604 puppetdb
  adduser -G puppetdb -u 64604 -h /opt/puppetlabs/server/data/puppetdb -H -D -s /sbin/nologin puppetdb
else
  groupadd --gid 64604 puppetdb
  useradd \
    --gid puppetdb \
    --home-dir /opt/puppetlabs/server/data/puppetdb \
    --no-create-home \
    --shell /usr/sbin/nologin \
    --uid 64604 \
    puppetdb
fi

mkdir -p "$LOGDIR"

chown -R puppetdb:puppetdb /etc/puppetlabs/puppetdb
chown -R puppetdb:puppetdb /opt/puppetlabs/server/data/puppetdb
chown -R puppetdb:puppetdb /var/log/puppetlabs/puppetdb
chown -R puppetdb:puppetdb /var/run/puppetlabs/puppetdb
chown -R puppetdb:puppetdb "$LOGDIR"

# We want to use the HOCON database.conf and config.conf files, so get rid of the packaged files
rm -f /etc/puppetlabs/puppetdb/conf.d/database.ini
rm -f /etc/puppetlabs/puppetdb/conf.d/config.ini

# /opt/puppetlabs/server/bin/puppetdb config-migration
# /opt/puppetlabs/server/bin/puppetdb ssl-setup

sed -i /init_restart_file/d /opt/puppetlabs/server/apps/puppetdb/cli/apps/foreground

rm /prep_release_container.sh
