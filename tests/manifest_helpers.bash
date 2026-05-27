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

assert_command_fails() {
  local output="$1"
  shift
  if ( "$@" ) >"$output" 2>&1; then
    fail "expected command to fail: $*"
  fi
}

assert_external_list_count() {
  local list="$1" expected="$2" count
  count="$(grep -c '^' "$list" || true)"
  [[ "$count" == "$expected" ]] || fail "expected $expected listed external entries in $list, found $count"
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

unrelated_path_manifest="$tmp/unrelated-path.json"
printf '%s\n' '{"name":"scoped","other":{"path":"/tmp/not-external"},"external":[]}' > "$unrelated_path_manifest"
manifest_external_list "$unrelated_path_manifest" > "$tmp/unrelated-path-list"
assert_external_list_count "$tmp/unrelated-path-list" 0
assert_list_not_contains "$tmp/unrelated-path-list" "/tmp/not-external"

manifest_external_add "$unrelated_path_manifest" "/tmp/external"
validate_manifest "$unrelated_path_manifest"
manifest_external_list "$unrelated_path_manifest" > "$tmp/unrelated-path-added-list"
assert_external_list_count "$tmp/unrelated-path-added-list" 1
assert_list_contains "$tmp/unrelated-path-added-list" "/tmp/external"
assert_list_not_contains "$tmp/unrelated-path-added-list" "/tmp/not-external"

manifest_external_remove "$unrelated_path_manifest" "/tmp/external"
validate_manifest "$unrelated_path_manifest"
manifest_external_list "$unrelated_path_manifest" > "$tmp/unrelated-path-removed-list"
assert_external_list_count "$tmp/unrelated-path-removed-list" 0
assert_list_not_contains "$tmp/unrelated-path-removed-list" "/tmp/not-external"
assert_file_contains "$unrelated_path_manifest" '"other":{"path":"/tmp/not-external"}'

nested_external_manifest="$tmp/nested-external.json"
printf '%s\n' '{"name":"nested","other":{"external":[{"path":"/tmp/nested-external","mode":"copy"}],"path":"/tmp/nested-path"},"external":[]}' > "$nested_external_manifest"
manifest_external_add "$nested_external_manifest" "/tmp/top-external"
validate_manifest "$nested_external_manifest"
manifest_external_list "$nested_external_manifest" > "$tmp/nested-external-added-list"
assert_external_list_count "$tmp/nested-external-added-list" 1
assert_list_contains "$tmp/nested-external-added-list" "/tmp/top-external"
assert_list_not_contains "$tmp/nested-external-added-list" "/tmp/nested-external"
assert_file_contains "$nested_external_manifest" '"other":{"external":[{"path":"/tmp/nested-external","mode":"copy"}],"path":"/tmp/nested-path"}'

manifest_external_remove "$nested_external_manifest" "/tmp/top-external"
validate_manifest "$nested_external_manifest"
manifest_external_list "$nested_external_manifest" > "$tmp/nested-external-removed-list"
assert_external_list_count "$tmp/nested-external-removed-list" 0
assert_list_not_contains "$tmp/nested-external-removed-list" "/tmp/nested-external"
assert_file_contains "$nested_external_manifest" '"other":{"external":[{"path":"/tmp/nested-external","mode":"copy"}],"path":"/tmp/nested-path"}'

nested_entry_manifest="$tmp/nested-entry.json"
printf '%s\n' '{"name":"nested-entry","external":[{"path":"/tmp/direct","metadata":{"path":"/tmp/nested-metadata","external":[{"path":"/tmp/nested-external"}]}}]}' > "$nested_entry_manifest"
manifest_external_list "$nested_entry_manifest" > "$tmp/nested-entry-list"
assert_external_list_count "$tmp/nested-entry-list" 1
assert_list_contains "$tmp/nested-entry-list" "/tmp/direct"
assert_list_not_contains "$tmp/nested-entry-list" "/tmp/nested-metadata"
assert_list_not_contains "$tmp/nested-entry-list" "/tmp/nested-external"

manifest_external_add "$nested_entry_manifest" "/tmp/added"
validate_manifest "$nested_entry_manifest"
manifest_external_list "$nested_entry_manifest" > "$tmp/nested-entry-added-list"
assert_external_list_count "$tmp/nested-entry-added-list" 2
assert_list_contains "$tmp/nested-entry-added-list" "/tmp/direct"
assert_list_contains "$tmp/nested-entry-added-list" "/tmp/added"
assert_list_not_contains "$tmp/nested-entry-added-list" "/tmp/nested-metadata"
assert_list_not_contains "$tmp/nested-entry-added-list" "/tmp/nested-external"

manifest_external_remove "$nested_entry_manifest" "/tmp/added"
validate_manifest "$nested_entry_manifest"
manifest_external_list "$nested_entry_manifest" > "$tmp/nested-entry-removed-list"
assert_external_list_count "$tmp/nested-entry-removed-list" 1
assert_list_contains "$tmp/nested-entry-removed-list" "/tmp/direct"
assert_list_not_contains "$tmp/nested-entry-removed-list" "/tmp/nested-metadata"
assert_list_not_contains "$tmp/nested-entry-removed-list" "/tmp/nested-external"

escaped_manifest="$tmp/escaped.json"
printf '{"name":"escaped","external":[]}\n' > "$escaped_manifest"
escaped_path='/tmp/path with "quote" and \backslash'
manifest_external_add "$escaped_manifest" "$escaped_path"
validate_manifest "$escaped_manifest"
assert_file_contains "$escaped_manifest" '/tmp/path with \"quote\" and \\backslash'
manifest_external_list "$escaped_manifest" > "$tmp/escaped-list"
assert_list_contains "$tmp/escaped-list" "$escaped_path"

cli_profile_dir="$HOME/.opencode-profiles/cli"
mkdir -p "$cli_profile_dir"
write_manifest "$cli_profile_dir" cli ""
register_profile cli "$cli_profile_dir"

deleted_external="$HOME/.local/share/deleted-external"
mkdir -p "$deleted_external"
cmd_external add cli "$deleted_external" >/dev/null
rm -rf "$deleted_external"
cmd_external remove cli "$deleted_external" >/dev/null
cmd_external list cli > "$tmp/deleted-external-list"
assert_list_not_contains "$tmp/deleted-external-list" "$deleted_external"

assert_command_fails "$tmp/remove-traversal-error" "$OCP" external remove cli "$HOME/../outside"
assert_file_contains "$tmp/remove-traversal-error" "external path must be under HOME"

mkdir -p "$HOME/.local/share/canonical-target"
ln -s "$HOME/.local/share/canonical-target" "$HOME/.local/share/canonical-link"
cmd_external add cli "$HOME/.local/share/canonical-link" >/dev/null
cmd_external remove cli "$HOME/.local/share/canonical-link" >/dev/null
cmd_external list cli > "$tmp/canonical-list"
assert_list_not_contains "$tmp/canonical-list" "$HOME/.local/share/canonical-target"

echo "manifest helper tests passed"
