#!/bin/bash
#
# Publish one build of an OpenVoxDB release under its build number. For the
# Ubuntu and the Alpine images, push the <db_version>-<n> tag and move the
# <db_version> and <release> tags, in ghcr.io and on Docker Hub. The manifest
# job of the Build and Publish workflow runs this on main only.
#
# Usage: publish_manifest.sh RELEASE DB_VERSION SEQUENCE REVISION
#
#   RELEASE     OpenVoxDB major release, e.g. 8, which is also the major tag
#   DB_VERSION  OpenVoxDB version, e.g. 8.18.1
#   SEQUENCE    the build number, from build_sequence.sh
#   REVISION    the commit the images were built from
#
# The per-platform images, <release>-<revision>-<os>-<platform>, must already
# be in ghcr.io. Each index records the commit it was built from, so a re-run
# of the same commit can publish its number again, while a number that another
# commit published, or one whose origin can't be checked, is never overwritten.

set -euo pipefail

usage="usage: $0 RELEASE DB_VERSION SEQUENCE REVISION"
release=${1:?$usage}
version=${2:?$usage}
sequence=${3-}
revision=${4:?$usage}

ghcr=ghcr.io/openvoxproject/openvoxdb
hub=docker.io/voxpupuli/openvoxdb

if ! [[ "$sequence" =~ ^[0-9]+$ ]]; then
  echo "::error::No build sequence number for $version"
  exit 1
fi
build_tag="$version-$sequence"

# A tag list that can't be read is an error, not an empty registry: reading it
# as empty would let the loop below overwrite a published number.
existing_tags=$(skopeo list-tags "docker://$ghcr")
if ! jq -e '.Tags | type == "array"' > /dev/null <<< "$existing_tags"; then
  echo "::error::could not read the tag list of $ghcr; refusing to publish."
  exit 1
fi

for tag in "$build_tag" "$build_tag-alpine"; do
  if jq -e --arg tag "$tag" 'any(.Tags[]; . == $tag)' > /dev/null <<< "$existing_tags"; then
    built_from=$(skopeo inspect --raw "docker://$ghcr:$tag" \
      | jq -r '.annotations["org.opencontainers.image.revision"] // ""')
    if [ "$built_from" != "$revision" ]; then
      echo "::error::$tag already exists and was not built from $revision; refusing to overwrite it. Re-run all jobs to get a new build number."
      exit 1
    fi
  fi
done

# publish OS SUFFIX: tag one multi-architecture index for OS in both registries.
publish() {
  local os=$1 suffix=$2
  docker buildx imagetools create \
    --annotation "index:org.opencontainers.image.revision=$revision" \
    -t "$ghcr:$build_tag$suffix" -t "$ghcr:$version$suffix" -t "$ghcr:$release$suffix" \
    -t "$hub:$build_tag$suffix" -t "$hub:$version$suffix" -t "$hub:$release$suffix" \
    "$ghcr:$release-$revision-$os-arm64" "$ghcr:$release-$revision-$os-amd64"
}

publish ubuntu ""
publish alpine -alpine

if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
  echo "Published $build_tag and $build_tag-alpine from $revision" >> "$GITHUB_STEP_SUMMARY"
fi
