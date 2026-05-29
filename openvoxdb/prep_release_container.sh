#!/usr/bin/env bash

apk update
apk add --no-cache dumb-init runuser coreutils gcompat

# Create puppet user and group, and set permissions on necessary directories
# Used for rootless execution of the container and to match permissions expected by Puppet Server
addgroup -g 1001 puppetdb
adduser -G puppetdb -u 1001 -h /opt/puppetlabs/server/data/puppetdb -H -D -s /sbin/nologin puppetdb

mkdir -p $LOGDIR

chown -R puppetdb:puppetdb /etc/puppetlabs/puppetdb
chown -R puppetdb:puppetdb /opt/puppetlabs/server/data/puppetdb
chown -R puppetdb:puppetdb /var/log/puppetlabs/puppetdb
chown -R puppetdb:puppetdb /var/run/puppetlabs/puppetdb
chown -R puppetdb:puppetdb $LOGDIR

# We want to use the HOCON database.conf and config.conf files, so get rid of the packaged files
rm -f /etc/puppetlabs/puppetdb/conf.d/database.ini
rm -f /etc/puppetlabs/puppetdb/conf.d/config.ini

# /opt/puppetlabs/server/bin/puppetdb config-migration
# /opt/puppetlabs/server/bin/puppetdb ssl-setup

sed -i /init_restart_file/d /opt/puppetlabs/server/apps/puppetdb/cli/apps/foreground

rm /prep_release_container.sh
