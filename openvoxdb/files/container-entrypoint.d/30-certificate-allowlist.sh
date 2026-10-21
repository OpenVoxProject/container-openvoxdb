#!/bin/bash
set -e

if [ "$OPENVOXDB_CERTIFICATE_ALLOWLIST" != "" ]; then
  hocon -f /etc/puppetlabs/puppetdb/conf.d/puppetdb.conf set puppetdb.certificate-allowlist certificate-allowlist
  IFS=','
  for cert in $OPENVOXDB_CERTIFICATE_ALLOWLIST; do
    echo $cert >>/opt/puppetlabs/server/apps/puppetdb/certificate-allowlist
  done
fi
