#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OCP="$ROOT/bin/ocp"

fail() { echo "test failure: $*" >&2; exit 1; }
assert_file_contains() { grep -Fq "$2" "$1" || fail "expected $1 to contain: $2"; }
assert_file_not_contains() { ! grep -Fq "$2" "$1" || fail "expected $1 not to contain: $2"; }
assert_list_contains() { grep -Fxq "$2" "$1" || fail "expected $1 to list: $2"; }
assert_list_not_contains() { ! grep -Fxq "$2" "$1" || fail "expected $1 not to list: $2"; }

load_ocp_helpers() {
  # Drop the final main dispatch so this test can call private helpers directly.
  # shellcheck disable=SC1090
  source <(sed '$d' "$OCP")
}

validate_manifest() {
  local manifest="$1"
  if command -v jq >/dev/null 2>&1; then
    jq empty "$manifest" >/dev/null || fail "manifest is not valid JSON: $manifest"
  fi
}

assert_external_count() {
  local manifest="$1" expected="$2" count
  count="$(grep -c '"path"[[:space:]]*:' "$manifest" || true)"
  [[ "$count" == "$expected" ]] || fail "expected $expected external entries in $manifest, found $count"
}

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

export HOME="$tmp/home"
export XDG_CONFIG_HOME="$tmp/config"
export XDG_DATA_HOME="$tmp/data"
mkdir -p "$HOME" "$XDG_CONFIG_HOME" "$XDG_DATA_HOME"

load_ocp_helpers

ensure_global_manifest
global_manifest="$(global_manifest_path)"
global_path="$HOME/.local/share/global-extra"
manifest_external_add "$global_manifest" "$global_path"
validate_manifest "$global_manifest"
manifest_external_list "$global_manifest" > "$tmp/global-list"
assert_list_contains "$tmp/global-list" "$global_path"
manifest_external_remove "$global_manifest" "$global_path"
validate_manifest "$global_manifest"
manifest_external_list "$global_manifest" > "$tmp/global-list-removed"
assert_list_not_contains "$tmp/global-list-removed" "$global_path"

profile_dir="$HOME/.opencode-profiles/alpha"
mkdir -p "$profile_dir"
write_manifest "$profile_dir" alpha ""
profile_manifest="$(manifest_path "$profile_dir")"
profile_path="$HOME/.local/share/profile-extra"
manifest_external_add "$profile_manifest" "$profile_path"
validate_manifest "$profile_manifest"
assert_file_contains "$profile_manifest" '"external": ['
manifest_external_list "$profile_manifest" > "$tmp/profile-list"
assert_list_contains "$tmp/profile-list" "$profile_path"

compact_empty="$tmp/compact-empty.json"
printf '{"name":"compact","external":[]}\n' > "$compact_empty"
manifest_external_add "$compact_empty" "/tmp/compact-empty-extra"
validate_manifest "$compact_empty"
manifest_external_list "$compact_empty" > "$tmp/compact-empty-list"
assert_list_contains "$tmp/compact-empty-list" "/tmp/compact-empty-extra"

compact_populated="$tmp/compact-populated.json"
printf '{"name":"compact","external":[{"path":"/tmp/one","mode":"copy"}]}\n' > "$compact_populated"
manifest_external_add "$compact_populated" "/tmp/two"
validate_manifest "$compact_populated"
manifest_external_add "$compact_populated" "/tmp/two"
validate_manifest "$compact_populated"
assert_external_count "$compact_populated" 2
manifest_external_list "$compact_populated" > "$tmp/compact-populated-list"
assert_list_contains "$tmp/compact-populated-list" "/tmp/one"
assert_list_contains "$tmp/compact-populated-list" "/tmp/two"

manifest_external_remove "$compact_populated" "/tmp/one"
validate_manifest "$compact_populated"
manifest_external_list "$compact_populated" > "$tmp/compact-populated-removed-list"
assert_list_not_contains "$tmp/compact-populated-removed-list" "/tmp/one"
assert_list_contains "$tmp/compact-populated-removed-list" "/tmp/two"
assert_file_not_contains "$compact_populated" '{}'

escaped_manifest="$tmp/escaped.json"
printf '{"name":"escaped","external":[]}\n' > "$escaped_manifest"
escaped_path='/tmp/path with "quote" and \backslash'
manifest_external_add "$escaped_manifest" "$escaped_path"
validate_manifest "$escaped_manifest"
assert_file_contains "$escaped_manifest" '/tmp/path with \"quote\" and \\backslash'
manifest_external_list "$escaped_manifest" > "$tmp/escaped-list"
assert_list_contains "$tmp/escaped-list" "$escaped_path"

echo "manifest helper tests passed"
