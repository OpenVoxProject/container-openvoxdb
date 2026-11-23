#!/usr/bin/env bash
#
# Check that openvoxdb/prep_build_container.sh stops at the first file missing
# from the OpenVoxDB tarball, rather than carrying on and building an image
# without it.
#
# The script runs inside the image under test, as root, against a tarball that
# holds only an empty puppetdb-<version> directory. It must fail on the first
# file it installs and go no further.
#
# Usage: tests/prep_build_test.sh <image>

set -euo pipefail

image=${1:?usage: $0 <image>}
root=$(cd "$(dirname "$0")/.." && pwd)
work=$(mktemp -d)
trap 'rm -rf "${work}"' EXIT

version=0.0.0-test
mkdir "${work}/puppetdb-${version}"
tar -c -z -f "${work}/openvoxdb-${version}.tar.gz" -C "${work}" "puppetdb-${version}"

rc=0
docker run --rm --user 0 --entrypoint bash \
  -e OPENVOXDB_VERSION="${version}" \
  -v "${work}/openvoxdb-${version}.tar.gz:/openvoxdb-${version}.tar.gz:ro" \
  -v "${root}/openvoxdb/prep_build_container.sh:/prep_build_container.sh:ro" \
  "${image}" /prep_build_container.sh > "${work}/stdout" 2> "${work}/stderr" || rc=$?
err=$(cat "${work}/stderr")

# The first file the script installs, and one it installs much later.
first=ext/puppetdb.logrotate.conf
later=ext/cli/foreground

if [ "${rc}" -eq 0 ]; then
  echo "FAIL: prep_build_container.sh exited 0 with files missing" >&2
  exit 1
elif ! grep -qF "${first}" <<< "${err}"; then
  echo "FAIL: prep_build_container.sh did not fail on ${first} (exit ${rc}): ${err}" >&2
  exit 1
elif grep -qF "${later}" <<< "${err}"; then
  echo "FAIL: prep_build_container.sh carried on after the first missing file: ${err}" >&2
  exit 1
fi
echo "ok   prep_build_container.sh stops at the first missing file (${image})"
