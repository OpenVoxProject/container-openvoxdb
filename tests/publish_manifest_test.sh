#!/usr/bin/env bash
#
# Tests for publish_manifest.sh, run the way the "Create build manifest" step
# in .sync.yml runs it: the test extracts that step's command, fills in the
# GitHub Actions expressions, and runs it from the repository root with skopeo
# and docker stubbed out. That covers the arguments the step passes as well as
# the script.
#
# It checks that a new build number is published with exactly the expected
# tags, that a number the same commit already published is published again,
# and that a number another commit published, or one that can't be verified,
# is refused without pushing anything.
#
# Usage: tests/publish_manifest_test.sh (needs yq and jq; no registry access)

set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
work=$(mktemp -d)
trap 'rm -rf "${work}"' EXIT

sha=0123456789abcdef0123456789abcdef01234567
other=fedcba9876543210fedcba9876543210fedcba98
version=8.18.1
release=8

yq -r '.".github/workflows/build_container.yml".publish_manifest_steps[]
  | select(.name == "Create build manifest") | .commands[]' \
  "${root}/.sync.yml" > "${work}/step.template"
if [ ! -s "${work}/step.template" ]; then
  echo "FAIL: no \"Create build manifest\" step in .sync.yml"
  exit 1
fi

# Stubs: skopeo serves the tag list and image indexes from the case directory,
# docker records each call instead of pushing.
mkdir "${work}/bin"
cat > "${work}/bin/skopeo" <<'EOF'
#!/usr/bin/env bash
case "$1" in
  list-tags)
    [ -f "${CASE_DIR}/list-fails" ] && { echo "skopeo: list failed" >&2; exit 1; }
    cat "${CASE_DIR}/tags.json"
    ;;
  inspect)
    ref=${*: -1}
    cat "${CASE_DIR}/index-${ref##*:}.json" 2> /dev/null \
      || { echo "skopeo: manifest unknown" >&2; exit 1; }
    ;;
  *) echo "skopeo stub: unexpected $*" >&2; exit 2 ;;
esac
EOF
cat > "${work}/bin/docker" <<'EOF'
#!/usr/bin/env bash
echo "$*" >> "${CASE_DIR}/docker.log"
EOF
chmod +x "${work}/bin/skopeo" "${work}/bin/docker"

index() {
  if [ -n "$1" ]; then
    jq -cn --arg rev "$1" '{annotations: {"org.opencontainers.image.revision": $rev}}'
  else
    echo '{"manifests": []}'
  fi
}

# The two docker calls a publish must make: each pushes the build-numbered,
# version and major tags of one OS to both registries, annotated with the
# commit, from that OS's two per-platform images.
expected_calls() {
  local sequence=$1 os suffix ghcr=ghcr.io/openvoxproject/openvoxdb hub=docker.io/voxpupuli/openvoxdb
  for os in ubuntu alpine; do
    suffix=
    [ "${os}" = alpine ] && suffix=-alpine
    echo "buildx imagetools create --annotation index:org.opencontainers.image.revision=${sha}" \
      "-t ${ghcr}:${version}-${sequence}${suffix} -t ${ghcr}:${version}${suffix} -t ${ghcr}:${release}${suffix}" \
      "-t ${hub}:${version}-${sequence}${suffix} -t ${hub}:${version}${suffix} -t ${hub}:${release}${suffix}" \
      "${ghcr}:${release}-${sha}-${os}-arm64 ${ghcr}:${release}-${sha}-${os}-amd64"
  done
}

failures=0

# run_case NAME EXPECT TAGS_JSON SEQUENCE [MESSAGE] [TAG=REVISION...]
#   EXPECT is "publish" or "refuse"; MESSAGE is text the output must contain;
#   each TAG=REVISION writes that tag's image index (empty REVISION: none).
run_case() {
  local name=$1 expect=$2 tags=$3 sequence=$4 message=${5:-}
  shift 5 || shift $#
  local dir rc=0 out pair
  dir=$(mktemp -d "${work}/case.XXXXXX")
  if [ "${tags}" = FAIL ]; then
    touch "${dir}/list-fails"
  else
    printf '%s' "${tags}" > "${dir}/tags.json"
  fi
  for pair in "$@"; do
    index "${pair#*=}" > "${dir}/index-${pair%%=*}.json"
  done
  sed -e "s|\${{ fromJSON(needs.setup-matrix.outputs.build-sequence)\[matrix.db_version\] }}|${sequence}|g" \
    -e "s|\${{ matrix.db_version }}|${version}|g" \
    -e "s|\${{ matrix.release }}|${release}|g" \
    -e "s|\${{ github.sha }}|${sha}|g" \
    "${work}/step.template" > "${dir}/step.sh"
  # shellcheck disable=SC2016 # a literal GitHub Actions expression
  if grep -q '\${{' "${dir}/step.sh"; then
    # shellcheck disable=SC2016 # a literal GitHub Actions expression
    echo "FAIL ${name}: unsubstituted expression: $(grep -o '\${{[^}]*}}' "${dir}/step.sh" | head -1)"
    failures=$((failures + 1))
    return
  fi
  : > "${dir}/summary"
  out=$(cd "${root}" && CASE_DIR="${dir}" GITHUB_STEP_SUMMARY="${dir}/summary" \
    PATH="${work}/bin:${PATH}" bash -e "${dir}/step.sh" 2>&1) || rc=$?

  if [ "${expect}" = publish ]; then
    if [ "${rc}" -ne 0 ]; then
      echo "FAIL ${name}: exit ${rc}, want 0: ${out}"
    elif [ "$(cat "${dir}/docker.log" 2> /dev/null)" != "$(expected_calls "${sequence}")" ]; then
      echo "FAIL ${name}: docker calls differ from the expected tag set:"
      diff <(expected_calls "${sequence}") "${dir}/docker.log" || true
    elif ! grep -qF "Published ${version}-${sequence} and ${version}-${sequence}-alpine from ${sha}" "${dir}/summary"; then
      echo "FAIL ${name}: job summary lacks the published tags: $(cat "${dir}/summary")"
    else
      echo "ok   ${name}"
      return
    fi
  else
    if [ "${rc}" -eq 0 ]; then
      echo "FAIL ${name}: exit 0, want a refusal: ${out}"
    elif [ -s "${dir}/docker.log" ]; then
      echo "FAIL ${name}: pushed despite refusing: $(cat "${dir}/docker.log")"
    elif [ -n "${message}" ] && ! grep -qF -- "${message}" <<< "${out}"; then
      echo "FAIL ${name}: output lacks '${message}': ${out}"
    else
      echo "ok   ${name}"
      return
    fi
  fi
  failures=$((failures + 1))
}

run_case "a new build number is published" publish \
  '{"Tags":["8.18.1","8.18.1-main","8.18.1-1","8.18.1-1-alpine"]}' 2 ""
run_case "a re-run of the same commit re-publishes its number" publish \
  '{"Tags":["8.18.1-2","8.18.1-2-alpine"]}' 2 "" \
  "8.18.1-2=${sha}" "8.18.1-2-alpine=${sha}"
run_case "a re-run completes a number only half published" publish \
  '{"Tags":["8.18.1-2"]}' 2 "" "8.18.1-2=${sha}"
run_case "a number another commit published is not overwritten" refuse \
  '{"Tags":["8.18.1-2","8.18.1-2-alpine"]}' 2 "8.18.1-2 already exists and was not built from ${sha}" \
  "8.18.1-2=${other}" "8.18.1-2-alpine=${other}"
run_case "an Alpine-only number from another commit is not overwritten" refuse \
  '{"Tags":["8.18.1-2-alpine"]}' 2 "8.18.1-2-alpine already exists" \
  "8.18.1-2-alpine=${other}"
run_case "a number without a revision annotation is not overwritten" refuse \
  '{"Tags":["8.18.1-2"]}' 2 "8.18.1-2 already exists" "8.18.1-2="
run_case "a tag listing without .Tags is refused, not read as empty" refuse \
  '{"Repository":"ghcr.io/openvoxproject/openvoxdb"}' 2 "could not read the tag list"
run_case "a failed tag listing is refused" refuse FAIL 2 "skopeo: list failed"
run_case "a missing build number is refused" refuse '{"Tags":[]}' "" \
  "No build sequence number for ${version}"

exit $((failures > 0))
