#!/bin/bash
# bash is required to pass ENV vars with dots as sh cannot

set -e

echoerr() { echo "$@" 1>&2; }

echoerr "DEPRECATED: Use /container-entrypoint.sh instead of /docker-entrypoint.sh"
exec ./container-entrypoint.sh "$@"
