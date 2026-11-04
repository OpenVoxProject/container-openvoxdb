#!/usr/bin/env bash
#
# Check that matrix.sh accepts build_versions.yaml with exactly one
# `latest: true` release and rejects zero or two, in both modes; that the
# matrices it prints have the expected shape; and that it aborts and cleans up
# when build_versions.yaml can't be parsed.
#
# Usage: tests/matrix_test.sh (needs yq and jq, like matrix.sh)

set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
work=$(mktemp -d)
trap 'rm -rf "${work}"' EXIT

releases=$(yq '.include | length' "${root}/build_versions.yaml")
platforms=$(yq '.platforms | length' "${root}/build_platforms.yaml")

# The $releases and $platforms below are jq variables, passed with --argjson.
# One entry per release and platform, each carrying the fields the CI and
# publish workflows read, and one latest entry per platform for the CI guard
# that picks where tests/matrix_test.sh runs.
# shellcheck disable=SC2016
build_shape='.include | length == ($releases * $platforms)
  and all(.[]; [.release, .db_version, .jdk_version, .pql_version, .platform,
    .runner, .os] | all(type == "string" and length > 0))
  and ([.[] | select(.latest == true)] | length == $platforms)'
# One entry per release, exactly one of them latest.
# shellcheck disable=SC2016
tag_shape='.include | length == $releases
  and all(.[]; ([.release, .db_version] | all(type == "string" and length > 0))
    and (.latest | type) == "boolean")
  and ([.[] | select(.latest == true)] | length == 1)'

failures=0

# run <variant> <mode> <expected exit, or "nonzero"> [expected stderr text]
#     [jq check on stdout] [stderr text that must not appear]
run() {
  local variant=$1 mode=$2 want_rc=$3 want_msg=${4:-} shape=${5:-} reject_msg=${6:-}
  local dir="${work}/${variant}-${mode}" rc=0 out err
  mkdir -p "${dir}"
  cp "${root}/matrix.sh" "${root}/build_platforms.yaml" "${dir}/"
  case "${variant}" in
    current) cp "${root}/build_versions.yaml" "${dir}/" ;;
    none) yq 'del(.include[].latest)' "${root}/build_versions.yaml" > "${dir}/build_versions.yaml" ;;
    two) yq 'del(.include[].latest) | .include[0].latest = true | .include[1].latest = true' \
      "${root}/build_versions.yaml" > "${dir}/build_versions.yaml" ;;
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
  elif [ -n "${reject_msg}" ] && grep -qF "${reject_msg}" <<< "${err}"; then
    echo "FAIL ${variant}/${mode}: stderr has '${reject_msg}': ${err}"
    failures=$((failures + 1))
  elif [ -n "${shape}" ] && ! jq -e --argjson releases "${releases}" --argjson platforms "${platforms}" \
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
for mode in build tag; do
  run none "${mode}" 1 "exactly one release must set latest: true (found 0)"
  run two "${mode}" 1 "exactly one release must set latest: true (found 2)"
  # Unparseable YAML must abort the script at yq (set -e), before the latest
  # check runs, and still clean up.
  run broken "${mode}" nonzero "bad file 'build_versions.yaml'" "" \
    "exactly one release must set latest"
done

exit $((failures > 0))
