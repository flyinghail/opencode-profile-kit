#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OCP="$ROOT/bin/ocp"
README="$ROOT/README.md"

fail() {
  echo "test failure: $*" >&2
  exit 1
}

assert_not_contains() {
  local file="$1" unexpected="$2"
  if grep -Fq "$unexpected" "$file"; then
    fail "expected $file not to contain: $unexpected"
  fi
}

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

export HOME="$tmp/home"
export XDG_CONFIG_HOME="$tmp/config"
export XDG_DATA_HOME="$tmp/data"
export OC_BIN_DIR="$tmp/bin"
mkdir -p "$HOME" "$XDG_CONFIG_HOME" "$XDG_DATA_HOME" "$OC_BIN_DIR"

if "$OCP" capture demo -- true >"$tmp/capture.out" 2>&1; then
  fail "capture command unexpectedly succeeded"
fi
grep -Fq "unknown command: capture" "$tmp/capture.out" || fail "capture should be an unknown command"

"$OCP" help > "$tmp/help.out"
assert_not_contains "$tmp/help.out" "ocp capture"

"$OCP" completion bash > "$tmp/completion.bash"
assert_not_contains "$tmp/completion.bash" "capture"

assert_not_contains "$README" "ocp capture"
assert_not_contains "$README" "Capturing Global Installers"
assert_not_contains "$README" 'eval "$(ocp env my-profile)"'

awk '
  /^## Installing Into a Profile$/ { in_section=1; next }
  in_section && /^---$/ { in_section=0 }
  in_section { print }
' "$README" > "$tmp/installing-section.md"
grep -Fq "ocp shell my-profile" "$tmp/installing-section.md" || fail "Installing Into a Profile should use ocp shell"
assert_not_contains "$tmp/installing-section.md" "eval"

echo "capture removal tests passed"
