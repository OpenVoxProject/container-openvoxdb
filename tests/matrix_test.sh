#!/usr/bin/env bash
#
# Check that the matrices matrix.sh prints have the expected shape, that it
# rejects a missing or unknown mode, and that it aborts and cleans up when
# build_versions.yaml can't be parsed.
#
# Usage: tests/matrix_test.sh (needs yq and jq, like matrix.sh)

set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
work=$(mktemp -d)
trap 'rm -rf "${work}"' EXIT

releases=$(yq '.include | length' "${root}/build_versions.yaml")
platforms=$(yq '.platforms | length' "${root}/build_platforms.yaml")
# What matrix.sh reads, so the checks below can compare values, not just shape.
versions_json=$(yq -o=json -I=0 '.include' "${root}/build_versions.yaml")
platforms_json=$(yq -o=json -I=0 '.platforms' "${root}/build_platforms.yaml")

# The $releases, $platforms, $versions and $plats below are jq variables, passed
# with --argjson.
# One entry per release and platform, no two alike, each carrying the fields
# the CI and publish workflows read: every platform row from
# build_platforms.yaml, and each release's versions from build_versions.yaml.
# shellcheck disable=SC2016
build_shape='.include | length == ($releases * $platforms)
  and ([.[] | [.release, .os, .platform]] | unique | length) == ($releases * $platforms)
  and ([.[] | {platform, runner, os}] | unique)
    == ($plats | map({platform, runner, os}) | unique)
  and (($versions | map({key: .release, value: .}) | from_entries) as $by_release
    | all(.[]; $by_release[.release] as $v
      | .db_version == $v.db_version and .jdk_version == $v.jdk_version
        and .pql_version == $v.pql_version))
  and all(.[]; [.release, .db_version, .jdk_version, .pql_version, .platform,
    .runner, .os] | all(type == "string" and length > 0))'
# One entry per release, no two alike, with the release and OpenVoxDB version
# from build_versions.yaml.
# shellcheck disable=SC2016
tag_shape='.include | length == $releases
  and ([.[] | .release] | unique | length) == $releases
  and [.[] | {release, db_version}] == ($versions | map({release, db_version}))
  and all(.[]; [.release, .db_version] | all(type == "string" and length > 0))'

failures=0

# run <variant> <mode> <expected exit, or "nonzero"> [expected stderr text]
#     [jq check on stdout]
run() {
  local variant=$1 mode=$2 want_rc=$3 want_msg=${4:-} shape=${5:-}
  local dir="${work}/${variant}-${mode}" rc=0 out err
  mkdir -p "${dir}"
  cp "${root}/matrix.sh" "${root}/build_platforms.yaml" "${dir}/"
  case "${variant}" in
    current) cp "${root}/build_versions.yaml" "${dir}/" ;;
    broken) printf 'include: [\n' > "${dir}/build_versions.yaml" ;;
  esac
  out=$(cd "${dir}" && bash matrix.sh "${mode}" 2> "${dir}/stderr") || rc=$?
  err=$(cat "${dir}/stderr")
  if { [ "${want_rc}" = nonzero ] && [ "${rc}" -eq 0 ]; } \
      || { [ "${want_rc}" != nonzero ] && [ "${rc}" -ne "${want_rc}" ]; }; then
    echo "FAIL ${variant}/${mode}: exit ${rc}, want ${want_rc}: ${err}"
    failures=$((failures + 1))
  elif [ -n "${want_msg}" ] && ! grep -qF "${want_msg}" <<< "${err}"; then
    echo "FAIL ${variant}/${mode}: stderr lacks '${want_msg}': ${err}"
    failures=$((failures + 1))
  elif [ -n "${shape}" ] && ! jq -e --argjson releases "${releases}" --argjson platforms "${platforms}" \
      --argjson versions "${versions_json}" --argjson plats "${platforms_json}" \
      "${shape}" <<< "${out}" > /dev/null 2>&1; then
    echo "FAIL ${variant}/${mode}: unexpected output: ${out}"
    failures=$((failures + 1))
  elif compgen -G "${dir}/*.json" > /dev/null; then
    echo "FAIL ${variant}/${mode}: left JSON files behind"
    failures=$((failures + 1))
  else
    echo "ok   ${variant}/${mode}"
  fi
}

run current build 0 "" "${build_shape}"
run current tag 0 "" "${tag_shape}"
run current "" 2 "usage:"
run current bogus 2 "usage:"
for mode in build tag; do
  # Unparseable YAML must abort the script at yq (set -e) and still clean up.
  # Only the file name is matched, not yq's wording, which varies by version.
  run broken "${mode}" nonzero "build_versions.yaml"
done

exit $((failures > 0))
