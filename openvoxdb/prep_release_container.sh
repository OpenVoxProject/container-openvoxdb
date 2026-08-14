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

# The container runs as UID 64604 by default, but any UID works. Everything the
# server needs to write is root-owned with group 0 mirroring the owner permissions
mkdir -p "$LOGDIR" "$SSLDIR"

chown -R 0:0 /etc/puppetlabs/puppetdb
chown -R 0:0 /opt/puppetlabs/server/data/puppetdb
chown -R 0:0 /var/log/puppetlabs/puppetdb
chown -R 0:0 /var/run/puppetlabs/puppetdb
chown -R 0:0 "$LOGDIR"

# group-0 perms for arbitrary UIDs
for d in /etc/puppetlabs /etc/logrotate.d /var/log/puppetlabs /var/run/puppetlabs /opt/puppetlabs "$LOGDIR"; do
  mkdir -p "$d"
  chgrp -R 0 "$d"
  chmod -R g=u "$d"
  find "$d" -type d -exec chmod g+s {} +
done

# empty USER lets foreground run under any UID
sed -i 's/^ *USER="puppetdb"/USER=""/' /etc/default/puppetdb

# We want to use the HOCON database.conf and config.conf files, so get rid of the packaged files
rm -f /etc/puppetlabs/puppetdb/conf.d/database.ini
rm -f /etc/puppetlabs/puppetdb/conf.d/config.ini

# /opt/puppetlabs/server/bin/puppetdb config-migration
# /opt/puppetlabs/server/bin/puppetdb ssl-setup

sed -i /init_restart_file/d /opt/puppetlabs/server/apps/puppetdb/cli/apps/foreground

rm /prep_release_container.sh
