#!/usr/bin/env bash

# Warning: This variable API is experimental so these variables may be subject
# to change in the future.

tar -x -z -f /openvoxdb-${OPENVOXDB_VERSION}.tar.gz -C /

cd /puppetdb-${OPENVOXDB_VERSION}

install -d "/etc/logrotate.d" -m 0755
install -d "/etc/puppetlabs/puppetdb" -m 0750
install -d "/etc/puppetlabs/puppetdb/conf.d" -m 0755
install -d "/opt/puppetlabs/bin" -m 0755
install -d "/opt/puppetlabs/server/apps/puppetdb" -m 0755
install -d "/opt/puppetlabs/server/apps/puppetdb/bin" -m 0755
install -d "/opt/puppetlabs/server/apps/puppetdb/cli" -m 0755
install -d "/opt/puppetlabs/server/apps/puppetdb/cli/apps" -m 0755
install -d "/opt/puppetlabs/server/apps/puppetdb/scripts" -m 0755
install -d "/opt/puppetlabs/server/bin" -m 0755
install -d "/opt/puppetlabs/server/data/puppetdb" -m 0770
install -d "/opt/puppetlabs/server/data/puppetdb/logs" -m 0750
install -d "/var/log/puppetlabs/puppetdb" -m 700
install -d "/var/run/puppetlabs/puppetdb" -m 0755

install -m 0644 ext/puppetdb.logrotate.conf "/etc/logrotate.d/puppetdb"

install -m 0644 ext/config/bootstrap.cfg         "/etc/puppetlabs/puppetdb/bootstrap.cfg"
install -m 0644 ext/config/logback.xml           "/etc/puppetlabs/puppetdb/logback.xml"
install -m 0644 ext/config/request-logging.xml   "/etc/puppetlabs/puppetdb/request-logging.xml"

install -m 0644 ext/config/conf.d/config.ini     "/etc/puppetlabs/puppetdb/conf.d/config.ini"
install -m 0644 ext/config/conf.d/repl.ini       "/etc/puppetlabs/puppetdb/conf.d/repl.ini"
install -m 0644 ext/config/conf.d/database.ini   "/etc/puppetlabs/puppetdb/conf.d/database.ini"
install -m 0644 ext/config/conf.d/jetty.ini      "/etc/puppetlabs/puppetdb/conf.d/jetty.ini"
install -m 0644 ext/config/conf.d/auth.conf      "/etc/puppetlabs/puppetdb/conf.d/auth.conf"

install -m 0644 puppetdb.jar                     "/opt/puppetlabs/server/apps/puppetdb"
install -m 0755 ext/ezbake-functions.sh          "/opt/puppetlabs/server/apps/puppetdb"
install -m 0644 ext/ezbake.manifest              "/opt/puppetlabs/server/apps/puppetdb"

install -m 0755 "ext/bin/puppetdb"               "/opt/puppetlabs/server/apps/puppetdb/bin/puppetdb"

install -m 0755 ext/cli/ssl-setup                "/opt/puppetlabs/server/apps/puppetdb/cli/apps/ssl-setup"
install -m 0755 ext/cli/start                    "/opt/puppetlabs/server/apps/puppetdb/cli/apps/start"
install -m 0755 ext/cli/upgrade                  "/opt/puppetlabs/server/apps/puppetdb/cli/apps/upgrade"
install -m 0755 ext/cli/anonymize                "/opt/puppetlabs/server/apps/puppetdb/cli/apps/anonymize"
install -m 0755 ext/cli/stop                     "/opt/puppetlabs/server/apps/puppetdb/cli/apps/stop"
install -m 0755 ext/cli/delete-reports           "/opt/puppetlabs/server/apps/puppetdb/cli/apps/delete-reports"
install -m 0755 ext/cli/reload                   "/opt/puppetlabs/server/apps/puppetdb/cli/apps/reload"
install -m 0755 ext/cli/config-migration         "/opt/puppetlabs/server/apps/puppetdb/cli/apps/config-migration"
install -m 0755 ext/cli/foreground               "/opt/puppetlabs/server/apps/puppetdb/cli/apps/foreground"
install -m 0755 ext/cli_defaults/cli-defaults.sh "/opt/puppetlabs/server/apps/puppetdb/cli/"

install -m 0755 install.sh                       "/opt/puppetlabs/server/apps/puppetdb/scripts"

ln -s "../apps/puppetdb/bin/puppetdb"        "/opt/puppetlabs/server/bin/puppetdb"
ln -s "../server/apps/puppetdb/bin/puppetdb" "/opt/puppetlabs/bin/puppetdb"
