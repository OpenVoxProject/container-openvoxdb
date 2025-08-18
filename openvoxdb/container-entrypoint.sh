#!/bin/bash
# bash is required to pass ENV vars with dots as sh cannot

set -e

echoerr() { echo "$@" 1>&2; }

if [ -d /docker-entrypoint.d ]; then
    echoerr "DEPRECATED: Use /container-entrypoint.d/ instead of /docker-entrypoint.d/"
    for f in /docker-entrypoint.d/*.sh; do
        echo "Running $f"
        "$f"
    done
fi

for f in /container-entrypoint.d/*.sh; do
    echo "Running $f"
    "$f"
done

if [ -d /docker-custom-entrypoint.d/ ]; then
    echoerr "DEPRECATED: Use /container-custom-entrypoint.d/ instead of /docker-custom-entrypoint.d/"
    find /docker-custom-entrypoint.d/ -type f -name "*.sh" \
        -exec echo Running {} \; -exec bash {} \;
fi

if [ -d /container-custom-entrypoint.d ]; then
    find /container-custom-entrypoint.d/ -type f -name "*.sh" \
        -exec echo Running {} \; -exec bash {} \;
fi

exec /opt/puppetlabs/bin/puppetdb "$@"
