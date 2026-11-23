#!/bin/bash

set -euo pipefail

mode=${1:-}
case "${mode}" in
  build | tag) ;;
  *)
    echo "usage: $0 build|tag" >&2
    exit 2
    ;;
esac

cleanup() {
  rm -f build_platforms.json build_versions.json
}
trap cleanup EXIT

yq -o=json build_platforms.yaml > build_platforms.json
yq -o=json build_versions.yaml > build_versions.json

case "${mode}" in
  build)
    jq -rc --slurp '{ include: [ .[1].include[] as $i | .[0].platforms[] as $p | $i + {"platform": $p.platform, "runner": $p.runner, "os": $p.os} ] }' build_platforms.json build_versions.json
    ;;
  tag)
    jq -cr '.include |= map({ release: .release, db_version: .db_version })' build_versions.json
    ;;
esac
