#!/bin/bash
#
# Tests for build_sequence.sh. Needs bash, jq and yq; no registry access.
# Run from anywhere: bash tests/build_sequence_test.sh

set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
script="$root/build_sequence.sh"
workdir=$(mktemp -d)
trap 'rm -rf "$workdir"' EXIT

failures=0

# run_script TAGS_JSON BUILD_VERSIONS_YAML [VERSION...]
#   Runs build_sequence.sh with TAGS_JSON as the tag list, in a scratch
#   directory holding BUILD_VERSIONS_YAML (none if empty). Sets out, err, rc.
run_script() {
  local tags=$1 yaml=$2 dir
  shift 2
  dir=$(mktemp -d "$workdir/run.XXXXXX")
  printf '%s' "$tags" > "$dir/tags.json"
  if [ -n "$yaml" ]; then
    printf '%s\n' "$yaml" > "$dir/build_versions.yaml"
  fi
  rc=0
  out=$(cd "$dir" && bash "$script" --tags "$dir/tags.json" "$@" 2> "$dir/stderr") || rc=$?
  err=$(cat "$dir/stderr")
}

# expect NAME EXPECTED
expect() {
  if [ "$rc" -ne 0 ]; then
    echo "FAIL: $1: exited $rc: $err"
    failures=$((failures + 1))
  elif [ "$out" != "$2" ]; then
    echo "FAIL: $1: expected $2, got $out"
    failures=$((failures + 1))
  else
    echo "ok: $1"
  fi
}

# check NAME EXPECTED TAGS_JSON VERSION...
check() {
  local name=$1 expected=$2 tags=$3
  shift 3
  run_script "$tags" "" "$@"
  expect "$name" "$expected"
}

# check_default NAME EXPECTED TAGS_JSON BUILD_VERSIONS_YAML
#   Runs with no VERSION arguments, as CI does.
check_default() {
  run_script "$3" "$4"
  expect "$1" "$2"
}

# check_fails NAME MESSAGE TAGS_JSON BUILD_VERSIONS_YAML [VERSION...]
#   Expects a non-zero exit with MESSAGE on stderr.
check_fails() {
  local name=$1 message=$2 tags=$3 yaml=$4
  shift 4
  run_script "$tags" "$yaml" "$@"
  if [ "$rc" -eq 0 ]; then
    echo "FAIL: $name: expected a non-zero exit, got $out"
    failures=$((failures + 1))
  elif ! grep -qF -- "$message" <<< "$err"; then
    echo "FAIL: $name: stderr lacks '$message': $err"
    failures=$((failures + 1))
  else
    echo "ok: $name"
  fi
}

# A skopeo stub for the registry path: it records what it was asked for, then
# prints the run directory's tag list, or fails if skopeo-fails is there.
stubs="$workdir/bin"
mkdir "$stubs"
cat > "$stubs/skopeo" <<'EOF'
#!/usr/bin/env bash
echo "$*" > "$STUB_DIR/skopeo.args"
if [ -f "$STUB_DIR/skopeo-fails" ]; then
  echo "skopeo: registry unreachable" >&2
  exit 1
fi
cat "$STUB_DIR/tags.json"
EOF
chmod +x "$stubs/skopeo"

# check_registry NAME QUERIED_REF IMAGE [fails]
#   Runs without --tags, as the setup job on main does, against the skopeo
#   stub with IMAGE set (unset if empty). Expects QUERIED_REF to be listed and
#   the number to follow its tags, or with "fails", a non-zero exit.
check_registry() {
  local name=$1 ref=$2 image=$3 fails=${4:-} dir
  dir=$(mktemp -d "$workdir/run.XXXXXX")
  printf '%s' '{"Tags":["8.18.1-4","8.18.1-4-alpine"]}' > "$dir/tags.json"
  if [ -n "$fails" ]; then
    touch "$dir/skopeo-fails"
  fi
  rc=0
  out=$(
    cd "$dir"
    if [ -n "$image" ]; then export IMAGE="$image"; else unset IMAGE; fi
    STUB_DIR="$dir" PATH="$stubs:$PATH" bash "$script" 8.18.1 2> "$dir/stderr"
  ) || rc=$?
  err=$(cat "$dir/stderr")
  if [ "$(cat "$dir/skopeo.args" 2> /dev/null)" != "list-tags docker://$ref" ]; then
    echo "FAIL: $name: queried '$(cat "$dir/skopeo.args" 2> /dev/null)', want 'list-tags docker://$ref'"
    failures=$((failures + 1))
  elif [ -n "$fails" ]; then
    if [ "$rc" -eq 0 ]; then
      echo "FAIL: $name: expected a non-zero exit, got $out"
      failures=$((failures + 1))
    elif ! grep -qF "skopeo: registry unreachable" <<< "$err"; then
      echo "FAIL: $name: stderr lacks the skopeo error: $err"
      failures=$((failures + 1))
    else
      echo "ok: $name"
    fi
  else
    expect "$name" '{"8.18.1":5}'
  fi
}

check "empty registry starts at 0" \
  '{"8.18.0":0}' \
  '{"Tags":[]}' 8.18.0

check "legacy -main and -vX.Y.Z tags are ignored" \
  '{"8.18.0":0}' \
  '{"Tags":["8.18.0","8.18.0-alpine","8.18.0-main","8.18.0-main-alpine","8.18.0-v1.2.3","8.18.0-v1.2.3-alpine","8","latest"]}' 8.18.0

check "next number follows the highest" \
  '{"8.18.0":2}' \
  '{"Tags":["8.18.0-0","8.18.0-0-alpine","8.18.0-1","8.18.0-1-alpine"]}' 8.18.0

check "numbers compare numerically, not as strings" \
  '{"8.18.0":11}' \
  '{"Tags":["8.18.0-9","8.18.0-10","8.18.0-2"]}' 8.18.0

check "an Alpine-only number is not reused" \
  '{"8.18.0":4}' \
  '{"Tags":["8.18.0-2","8.18.0-3-alpine"]}' 8.18.0

check "other versions and per-commit tags are ignored" \
  '{"8.18.0":1}' \
  '{"Tags":["8.18.0-0","8.18.1-7","8.18.01-5","18.18.0-6","8-0123abc-ubuntu-amd64","8.18.0-5-ubuntu-amd64"]}' 8.18.0

check "dots in the version are not regex wildcards" \
  '{"8.18.0":0}' \
  '{"Tags":["8x18y0-5","8.18.0x-3"]}' 8.18.0

check "each version is numbered independently" \
  '{"8.18.0":2,"9.2.0":0}' \
  '{"Tags":["8.18.0-1","9.1.0-4"]}' 8.18.0 9.2.0

check_default "with no VERSION, every db_version in build_versions.yaml is numbered" \
  "$(yq -r '.include[].db_version' "$root/build_versions.yaml" | jq -Rcn '[inputs | {(.): 0}] | add')" \
  '{"Tags":[]}' "$(cat "$root/build_versions.yaml")"

check_default "with no VERSION, each release is numbered from the registry" \
  '{"8.18.1":3,"9.2.1":0}' \
  '{"Tags":["8.18.1-2","9.2.0-5"]}' \
  "$(printf 'include:\n  - release: "8"\n    db_version: "8.18.1"\n  - release: "9"\n    db_version: "9.2.1"')"

check_fails "a build_versions.yaml with no versions fails" \
  "no OpenVoxDB versions to number" '{"Tags":[]}' 'include: []'

check_fails "a release without a db_version fails instead of numbering null" \
  "not an OpenVoxDB version: null" '{"Tags":[]}' \
  "$(printf 'include:\n  - release: "8"\n    server_version: "8.18.0"')"

check_fails "an unparseable build_versions.yaml fails" \
  "no OpenVoxDB versions to number" '{"Tags":[]}' 'include: ['

check_registry "without --tags, the default repository is queried" \
  ghcr.io/openvoxproject/openvoxdb ""

check_registry "IMAGE overrides the queried repository" \
  ghcr.io/example/openvoxdb ghcr.io/example/openvoxdb

check_registry "a failed registry query fails instead of returning 0" \
  ghcr.io/openvoxproject/openvoxdb "" fails

check_fails "malformed JSON fails instead of returning 0" \
  "the tag list is not valid JSON" '{"Tags":' "" 8.18.0

check_fails "a listing without .Tags fails instead of returning 0" \
  "tag list has no .Tags array" \
  '{"Repository":"ghcr.io/openvoxproject/openvoxdb"}' "" 8.18.0

if [ "$failures" -ne 0 ]; then
  echo "$failures test(s) failed"
  exit 1
fi
echo "all tests passed"
