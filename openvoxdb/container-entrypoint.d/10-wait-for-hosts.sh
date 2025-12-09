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

# Alpine as high as 3.9 seems to have failures reaching addresses sporadically
# In local repro scenarios, performing a DNS lookup with dig increases reliability
wait_for_host_name_resolution() {
  # host and dig are in the bind-tools Alpine package
  # k8s nodes may not be reachable with a ping
  # performing a dig prior to a host may help prime the cache in Alpine
  # https://github.com/Microsoft/opengcs/issues/303
  /wtfc.sh --timeout="${2}" --interval=1 --progress "dig $1 && host $1"
  # additionally log the DNS lookup information for diagnostic purposes
  NAME_RESOLVED=$?
  dig $1
  if [ $NAME_RESOLVED -ne 0 ]; then
    error "dependent service at $1 cannot be resolved or contacted"
  fi
}

wait_for_host_port() {
  # -v verbose -w connect / final net read timeout -z scan and don't send data
  /wtfc.sh --timeout=${3} --interval=1 --progress "nc -v -w 1 -z '${1}' ${2}"
  if [ $? -ne 0 ]; then
    error "host $1:$2 does not appear to be listening"
  fi
}

OPENVOXDB_WAITFORHOST_SECONDS=${OPENVOXDB_WAITFORHOST_SECONDS:-30}
OPENVOXDB_WAITFORPOSTGRES_SECONDS=${OPENVOXDB_WAITFORPOSTGRES_SECONDS:-60}
OPENVOXDB_WAITFORHEALTH_SECONDS=${OPENVOXDB_WAITFORHEALTH_SECONDS:-360}
OPENVOXDB_POSTGRES_HOSTNAME="${OPENVOXDB_POSTGRES_HOSTNAME:-postgres}"
OPENVOXSERVER_HOSTNAME="${OPENVOXSERVER_HOSTNAME:-puppet}"
OPENVOXSERVER_PORT="${OPENVOXSERVER_PORT:-8140}"

# wait for postgres DNS
wait_for_host_name_resolution $OPENVOXDB_POSTGRES_HOSTNAME $OPENVOXDB_WAITFORHOST_SECONDS

# wait for puppetserver DNS, then healthcheck
if [ "$USE_OPENVOXSERVER" = true ]; then
  wait_for_host_name_resolution $OPENVOXSERVER_HOSTNAME $OPENVOXDB_WAITFORHOST_SECONDS
  HEALTH_COMMAND="curl --silent --fail --insecure 'https://${OPENVOXSERVER_HOSTNAME}:"${OPENVOXSERVER_PORT}"/status/v1/simple' | grep -q '^running$'"
fi

if [ -n "$HEALTH_COMMAND" ]; then
  /wtfc.sh --timeout=$OPENVOXDB_WAITFORHEALTH_SECONDS --interval=1 --progress "$HEALTH_COMMAND"
  if [ $? -ne 0 ]; then
    error "Required health check failed"
  fi
fi

# wait for postgres
wait_for_host_port $OPENVOXDB_POSTGRES_HOSTNAME "${OPENVOXDB_POSTGRES_PORT:-5432}" $OPENVOXDB_WAITFORPOSTGRES_SECONDS
