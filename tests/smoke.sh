#!/usr/bin/env bash
#
# Start an OpenVoxDB image against a throwaway PostgreSQL, wait for it to
# report healthy and check the version it serves.
#
# With an OpenVox Server image as the fourth argument, the test runs the image's
# default TLS path instead: the server acts as the CA, OpenVoxDB fetches a
# certificate from it, and the test checks the HTTPS listener on port 8081.
#
# Usage: tests/smoke.sh <image> <expected version> [postgresql major] [openvoxserver image]

set -euo pipefail

usage="usage: $0 <image> <expected version> [postgresql major] [openvoxserver image]"
image=${1:?${usage}}
expected=${2:?${usage}}
pg_major=${3:-17}
server_image=${4:-}
# The TLS path also waits for the OpenVox Server CA to start before OpenVoxDB
# can fetch its certificate, so it gets longer to become healthy.
if [ -n "${server_image}" ]; then
  timeout=${SMOKE_TIMEOUT:-600}
else
  timeout=${SMOKE_TIMEOUT:-300}
fi

name="openvoxdb-smoke-$$"
network="${name}"
pg="${name}-postgres"
server="${name}-openvoxserver"
db="${name}-openvoxdb"

cleanup() {
  docker rm -f "${db}" "${server}" "${pg}" > /dev/null 2>&1 || true
  docker network rm "${network}" > /dev/null 2>&1 || true
}
trap cleanup EXIT

fail() {
  echo "smoke: $*" >&2
  for c in "${pg}" "${server}" "${db}"; do
    if docker inspect "${c}" > /dev/null 2>&1; then
      echo "----- ${c} logs -----" >&2
      docker logs "${c}" >&2 || true
    fi
  done
  exit 1
}

docker network create "${network}" > /dev/null

# The floating tag is deliberate: the test should track the PostgreSQL minor
# releases users run, not a pinned build.
docker run -d --name "${pg}" --network "${network}" \
  -e POSTGRES_USER=openvoxdb \
  -e POSTGRES_PASSWORD=openvoxdb \
  -e POSTGRES_DB=openvoxdb \
  "postgres:${pg_major}-alpine" > /dev/null

if [ -n "${server_image}" ]; then
  # Start the CA alongside PostgreSQL; OpenVoxDB waits for it to be healthy.
  # CI passes the floating openvoxserver:<release> tag on purpose: the test
  # should catch an incompatibility with the server release users pair with
  # this OpenVoxDB release. If the server image itself is broken, its logs are
  # printed on failure.
  docker run -d --name "${server}" --network "${network}" --network-alias puppet \
    -e USE_OPENVOXDB=false \
    "${server_image}" > /dev/null
fi

# The image's init phase only listens on the Unix socket, so a TCP answer means
# the final server is up.
pg_ready=false
for _ in $(seq 1 60); do
  if docker exec "${pg}" pg_isready -q -h 127.0.0.1 -U openvoxdb; then
    pg_ready=true
    break
  fi
  sleep 1
done
if [ "${pg_ready}" = false ]; then
  fail "PostgreSQL not ready after 60s"
fi
docker exec "${pg}" psql -q -h 127.0.0.1 -U openvoxdb -d openvoxdb \
  -c 'CREATE EXTENSION IF NOT EXISTS pg_trgm;'

if [ -n "${server_image}" ]; then
  use_server=true
else
  use_server=false
fi
docker run -d --name "${db}" --network "${network}" --network-alias openvoxdb \
  -e USE_OPENVOXSERVER="${use_server}" \
  -e OPENVOXDB_POSTGRES_HOSTNAME="${pg}" \
  "${image}" > /dev/null

deadline=$((SECONDS + timeout))
while :; do
  status=$(docker inspect -f '{{.State.Status}} {{.State.Health.Status}}' "${db}")
  case "${status}" in
    "running healthy") break ;;
    "running "*) ;;
    *) fail "container stopped (${status})" ;;
  esac
  if [ "${SECONDS}" -ge "${deadline}" ]; then
    fail "not healthy after ${timeout}s (${status})"
  fi
  sleep 5
done

version=$(docker exec "${db}" curl -fsS http://localhost:8080/pdb/meta/v1/version)
if ! grep -q "\"version\" *: *\"${expected}\"" <<< "${version}"; then
  fail "expected version ${expected}, got: ${version}"
fi

if [ "${use_server}" = true ]; then
  # Use the certificate the CA signed for this host as the client certificate.
  # shellcheck disable=SC2016 # expanded inside the container
  if ! docker exec "${db}" sh -c 'curl -fsS \
      --resolve "${CERTNAME}:8081:127.0.0.1" \
      --cacert "${SSLDIR}/certs/ca.pem" \
      --cert "${SSLDIR}/certs/server.crt" \
      --key "${SSLDIR}/private_keys/server.key" \
      "https://${CERTNAME}:8081/status/v1/services/puppetdb-status"' \
      | grep -q '"state":"running"'; then
    fail "HTTPS listener on 8081 did not answer with a CA-signed certificate"
  fi
  echo "smoke: ${image} is healthy over TLS and serves OpenVoxDB ${expected}"
else
  echo "smoke: ${image} is healthy and serves OpenVoxDB ${expected}"
fi
