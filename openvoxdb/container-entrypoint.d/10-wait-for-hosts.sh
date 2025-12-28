#!/bin/sh

set -e

# Wait on hosts to become available before proceeding
#
#
# Optional environment variables:
#   OPENVOXDB_WAITFORHOST_SECONDS     Number of seconds to wait for DNS names of
#                                    Postgres and Puppetserver to resolve, defaults to 30
#   OPENVOXDB_WAITFORHEALTH_SECONDS   Number of seconds to wait for health
#                                    checks of Puppetserver to succeed, defaults to 360
#                                    to match puppetserver healthcheck max wait
#   OPENVOXDB_WAITFORPOSTGRES_SECONDS Additional number of seconds to wait on Postgres,
#                                    after PuppetServer is healthy, defaults to 60
#   OPENVOXDB_POSTGRES_HOSTNAME       Specified in Dockerfile, defaults to postgres
#   OPENVOXSERVER_HOSTNAME            DNS name of puppetserver to wait on, defaults to puppet

msg() {
    echo "($0) $1"
}

error() {
    msg "Error: $1"
    exit 1
}

OPENVOXDB_WAITFORHOST_SECONDS=${OPENVOXDB_WAITFORHOST_SECONDS:-30}
OPENVOXDB_WAITFORPOSTGRES_SECONDS=${OPENVOXDB_WAITFORPOSTGRES_SECONDS:-60}
OPENVOXDB_WAITFORHEALTH_SECONDS=${OPENVOXDB_WAITFORHEALTH_SECONDS:-360}
OPENVOXDB_POSTGRES_HOSTNAME="${OPENVOXDB_POSTGRES_HOSTNAME:-postgres}"
OPENVOXSERVER_HOSTNAME="${OPENVOXSERVER_HOSTNAME:-puppet}"
OPENVOXSERVER_PORT="${OPENVOXSERVER_PORT:-8140}"

# wait for postgres is ready
/wtfc.sh --timeout="${OPENVOXDB_WAITFORHOST_SECONDS}" --interval=1 --progress "pg_isready -h ${OPENVOXDB_POSTGRES_HOSTNAME} --port '${OPENVOXDB_POSTGRES_PORT:-5432}'"

# wait for puppetserver DNS, then healthcheck
if [ "$USE_OPENVOXSERVER" = true ]; then
  HEALTH_COMMAND="curl --silent --fail --insecure 'https://${OPENVOXSERVER_HOSTNAME}:"${OPENVOXSERVER_PORT}"/status/v1/simple' | grep -q '^running$'"
fi

if [ -n "$HEALTH_COMMAND" ]; then
  /wtfc.sh --timeout=$OPENVOXDB_WAITFORHEALTH_SECONDS --interval=1 --progress "$HEALTH_COMMAND"
  if [ $? -ne 0 ]; then
    error "Required health check failed"
  fi
fi
