#!/bin/bash

set -euo pipefail

cleanup() {
  rm -f build_platforms.json build_versions.json
}
trap cleanup EXIT

yq -o=json build_platforms.yaml > build_platforms.json
yq -o=json build_versions.yaml > build_versions.json

# The floating latest tags follow exactly one release. Check in both modes so
# CI catches a mistake on the pull request, before anything is published.
latest_count=$(jq '[.include[] | select(.latest == true)] | length' build_versions.json)
if [ "$latest_count" -ne 1 ]; then
  echo "build_versions.yaml: exactly one release must set latest: true (found $latest_count)" >&2
  exit 1
fi

if [ "${1:-}" == "build" ]; then
  jq -rc --slurp '{ include: [ .[1].include[] as $i | .[0].platforms[] as $p | $i + {"platform": $p.platform, "runner": $p.runner, "os": $p.os} ] }' build_platforms.json build_versions.json
fi

if [ "${1:-}" == "tag" ]; then
  jq -cr '.include |= map({ release: .release, db_version: .db_version, latest: (.latest // false) })' build_versions.json
fi
