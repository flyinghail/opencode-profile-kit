#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OCP="$ROOT/bin/ocp"

fail() { echo "test failure: $*" >&2; exit 1; }
assert_file_contains() { grep -Fq "$2" "$1" || fail "expected $1 to contain: $2"; }
assert_file_not_contains() { ! grep -Fq "$2" "$1" || fail "expected $1 not to contain: $2"; }
assert_tar_contains() { tar -tzf "$1" | grep -Fxq "$2" || fail "expected archive $1 to contain: $2"; }
assert_dir_empty() { [[ -z "$(find "$1" -mindepth 1 -print -quit)" ]] || fail "expected directory to be empty: $1"; }

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

export HOME="$tmp/home"
export XDG_CONFIG_HOME="$tmp/config"
export XDG_DATA_HOME="$tmp/data"
export OC_BIN_DIR="$tmp/bin"
mkdir -p "$HOME" "$XDG_CONFIG_HOME" "$XDG_DATA_HOME" "$OC_BIN_DIR"
archives_dir="$tmp/archives"
mkdir -p "$archives_dir"

"$OCP" new alpha >/dev/null
alpha_dir="$HOME/.opencode-profiles/alpha"
printf 'profile config\n' > "$alpha_dir/opencode.json"
printf 'rewrite-paths=false\n' > "$alpha_dir/.ocp-recipes"

mkdir -p "$HOME/.local/share/alpha-extra"
printf 'extra\n' > "$HOME/.local/share/alpha-extra/data.txt"
"$OCP" external add alpha "$HOME/.local/share/alpha-extra"
mkdir -p "$HOME/tools/nested-extra"
printf 'nested extra\n' > "$HOME/tools/nested-extra/data.txt"
"$OCP" external add alpha "$HOME/tools/nested-extra"
"$OCP" external list alpha > "$tmp/external-list"
assert_file_contains "$tmp/external-list" "$HOME/.local/share/alpha-extra"
assert_file_contains "$tmp/external-list" "$HOME/tools/nested-extra"

(
  cd "$archives_dir"
  "$OCP" export alpha
)
profile_archive="$archives_dir/alpha.ocp-profile.tar.gz"
[[ -f "$profile_archive" ]] || fail "profile archive missing"
assert_tar_contains "$profile_archive" "metadata.env"
assert_tar_contains "$profile_archive" "profiles/alpha/opencode.json"
assert_tar_contains "$profile_archive" "profiles/alpha/.ocp-recipes"
assert_tar_contains "$profile_archive" "external/alpha/0/data.txt"
assert_tar_contains "$profile_archive" "external/alpha/0.type"
assert_tar_contains "$profile_archive" "external/alpha/1/data.txt"
assert_tar_contains "$profile_archive" "external/alpha/1.type"

mkdir -p "$HOME/data"
printf 'basename collision\n' > "$HOME/data/data"
"$OCP" external add alpha "$HOME/data"
collision_archive="$archives_dir/collision.ocp-profile.tar.gz"
"$OCP" export -f alpha "$collision_archive" >/dev/null
assert_tar_contains "$collision_archive" "external/alpha/2.type"
tar -xOzf "$collision_archive" external/alpha/2.type > "$tmp/collision-type"
assert_file_contains "$tmp/collision-type" "dir"

collision_home="$tmp/collision-home"
mkdir -p "$collision_home"
HOME="$collision_home" XDG_CONFIG_HOME="$tmp/collision-config" XDG_DATA_HOME="$tmp/collision-data" OC_BIN_DIR="$tmp/collision-bin" "$OCP" import "$collision_archive" >/dev/null
[[ -d "$collision_home/data" ]] || fail "expected basename-collision external path to restore as a directory"
assert_file_contains "$collision_home/data/data" "basename collision"

escape_stage="$tmp/escape-stage"
escape_archive="$archives_dir/escape.ocp-profile.tar.gz"
mkdir -p "$escape_stage/profiles/alpha" "$escape_stage/external/alpha/0" "$escape_stage/state"
cat > "$escape_stage/metadata.env" <<'META'
format_version="1"
kind="profile"
profiles="alpha"
global="0"
source_home="/source/home"
created_at="2026-01-01T00:00:00Z"
META
cat > "$escape_stage/profiles/alpha/.ocp-profile.json" <<'JSON'
{
  "name": "alpha",
  "external": [
    {
      "path": "/source/home/../../escaped",
      "mode": "copy"
    }
  ]
}
JSON
printf 'escape\n' > "$escape_stage/external/alpha/0/data.txt"
printf '/source/home/../../escaped\n' > "$escape_stage/external/alpha/0.target"
printf 'dir\n' > "$escape_stage/external/alpha/0.type"
(cd "$escape_stage" && tar -czf "$escape_archive" metadata.env profiles state external)
escape_home="$tmp/import-parent/inner/home"
outside_escape="$tmp/import-parent/escaped"
mkdir -p "$escape_home"
if HOME="$escape_home" XDG_CONFIG_HOME="$tmp/escape-config" XDG_DATA_HOME="$tmp/escape-data" OC_BIN_DIR="$tmp/escape-bin" "$OCP" import "$escape_archive" > "$tmp/escape.out" 2> "$tmp/escape.err"; then
  fail "expected escaping external target import to fail"
fi
assert_file_contains "$tmp/escape.err" "external target escapes HOME"
[[ ! -e "$outside_escape" ]] || fail "escaping external target wrote outside import HOME: $outside_escape"

equals_stage="$tmp/equals-stage"
equals_archive="$archives_dir/equals-source-home.ocp-profile.tar.gz"
mkdir -p "$equals_stage/profiles/alpha" "$equals_stage/external/alpha/0" "$equals_stage/state"
cat > "$equals_stage/metadata.env" <<'META'
format_version="1"
kind="profile"
profiles="alpha"
global="0"
source_home="/source/home=with=equals"
created_at="2026-01-01T00:00:00Z"
META
cat > "$equals_stage/profiles/alpha/.ocp-profile.json" <<'JSON'
{
  "name": "alpha",
  "external": [
    {
      "path": "/source/home=with=equals/arbitrary/nested/external-path",
      "mode": "copy"
    }
  ]
}
JSON
printf 'equals source home\n' > "$equals_stage/external/alpha/0/data.txt"
printf '/source/home=with=equals/arbitrary/nested/external-path\n' > "$equals_stage/external/alpha/0.target"
printf 'dir\n' > "$equals_stage/external/alpha/0.type"
(cd "$equals_stage" && tar -czf "$equals_archive" metadata.env profiles state external)
equals_import_home="$tmp/equals-import-home"
mkdir -p "$equals_import_home"
HOME="$equals_import_home" XDG_CONFIG_HOME="$tmp/equals-config" XDG_DATA_HOME="$tmp/equals-data" OC_BIN_DIR="$tmp/equals-bin" "$OCP" import "$equals_archive" >/dev/null
assert_file_contains "$equals_import_home/arbitrary/nested/external-path/data.txt" "equals source home"
[[ ! -e "$equals_import_home/external-path/data.txt" ]] || fail "source_home with equals fell back to basename external restore"

secret_global="$tmp/secret-global"
mkdir -p "$secret_global"
printf 'do not import\n' > "$secret_global/secret.txt"
symlink_global_stage="$tmp/symlink-global-stage"
symlink_global_archive="$archives_dir/symlink-global.ocp-global.tar.gz"
mkdir -p "$symlink_global_stage/global" "$symlink_global_stage/external" "$symlink_global_stage/state"
cat > "$symlink_global_stage/metadata.env" <<'META'
format_version="1"
kind="global"
profiles=""
global="1"
source_home="/source/home"
created_at="2026-01-01T00:00:00Z"
META
ln -s "$secret_global" "$symlink_global_stage/global/config"
printf '{"name":"global","external":[]}' > "$symlink_global_stage/global/.ocp-global.json"
(cd "$symlink_global_stage" && tar -czf "$symlink_global_archive" metadata.env global external state)
symlink_global_home="$tmp/symlink-global-home"
symlink_global_tmp="$tmp/symlink-global-tmp"
mkdir -p "$symlink_global_home" "$symlink_global_tmp"
if TMPDIR="$symlink_global_tmp" HOME="$symlink_global_home" XDG_CONFIG_HOME="$tmp/symlink-global-config" XDG_DATA_HOME="$tmp/symlink-global-data" OC_BIN_DIR="$tmp/symlink-global-bin" "$OCP" import "$symlink_global_archive" > "$tmp/symlink-global.out" 2> "$tmp/symlink-global.err"; then
  fail "expected symlinked global/config import to fail"
fi
assert_file_contains "$tmp/symlink-global.err" "archive contains symlink"
[[ ! -e "$symlink_global_home/.config/opencode/secret.txt" ]] || fail "symlinked global/config copied arbitrary local data"
assert_dir_empty "$symlink_global_tmp"

secret_external="$tmp/secret-external"
mkdir -p "$secret_external"
printf 'do not import\n' > "$secret_external/secret.txt"
symlink_external_stage="$tmp/symlink-external-stage"
symlink_external_archive="$archives_dir/symlink-external.ocp-global.tar.gz"
mkdir -p "$symlink_external_stage/global/config" "$symlink_external_stage/external/global" "$symlink_external_stage/state"
cat > "$symlink_external_stage/metadata.env" <<'META'
format_version="1"
kind="global"
profiles=""
global="1"
source_home="/source/home"
created_at="2026-01-01T00:00:00Z"
META
cat > "$symlink_external_stage/global/.ocp-global.json" <<'JSON'
{
  "name": "global",
  "external": [
    {
      "path": "/source/home/.local/share/symlink-external",
      "mode": "copy"
    }
  ]
}
JSON
ln -s "$secret_external" "$symlink_external_stage/external/global/0"
printf '/source/home/.local/share/symlink-external\n' > "$symlink_external_stage/external/global/0.target"
printf 'dir\n' > "$symlink_external_stage/external/global/0.type"
(cd "$symlink_external_stage" && tar -czf "$symlink_external_archive" metadata.env global external state)
symlink_external_home="$tmp/symlink-external-home"
symlink_external_tmp="$tmp/symlink-external-tmp"
mkdir -p "$symlink_external_home" "$symlink_external_tmp"
if TMPDIR="$symlink_external_tmp" HOME="$symlink_external_home" XDG_CONFIG_HOME="$tmp/symlink-external-config" XDG_DATA_HOME="$tmp/symlink-external-data" OC_BIN_DIR="$tmp/symlink-external-bin" "$OCP" import "$symlink_external_archive" > "$tmp/symlink-external.out" 2> "$tmp/symlink-external.err"; then
  fail "expected symlinked external payload import to fail"
fi
assert_file_contains "$tmp/symlink-external.err" "archive contains symlink"
[[ ! -e "$symlink_external_home/.local/share/symlink-external/secret.txt" ]] || fail "symlinked external payload copied arbitrary local data"
assert_dir_empty "$symlink_external_tmp"

mkdir -p "$HOME/.config/opencode"
printf 'global config\n' > "$HOME/.config/opencode/opencode.json"
mkdir -p "$XDG_CONFIG_HOME/opencode-profile-kit/global"
printf 'echo global\n' > "$XDG_CONFIG_HOME/opencode-profile-kit/global/.ocp-recipes"
mkdir -p "$HOME/.local/share/global-extra"
printf 'global extra\n' > "$HOME/.local/share/global-extra/data.txt"
"$OCP" external add -g "$HOME/.local/share/global-extra"

(
  cd "$archives_dir"
  "$OCP" export -g
)
global_archive="$archives_dir/global.ocp-global.tar.gz"
[[ -f "$global_archive" ]] || fail "global archive missing"
assert_tar_contains "$global_archive" "global/config/opencode.json"
assert_tar_contains "$global_archive" "global/.ocp-recipes"
assert_tar_contains "$global_archive" "global/.ocp-global.json"
assert_tar_contains "$global_archive" "external/global/0/data.txt"
assert_tar_contains "$global_archive" "external/global/0.type"

(
  cd "$archives_dir"
  "$OCP" export -a -g
)
all_archive="$archives_dir/all-with-global.ocp.tar.gz"
[[ -f "$all_archive" ]] || fail "all-with-global archive missing"
assert_tar_contains "$all_archive" "profiles/alpha/opencode.json"
assert_tar_contains "$all_archive" "global/config/opencode.json"

import_home="$tmp/import-home"
mkdir -p "$import_home"
HOME="$import_home" XDG_CONFIG_HOME="$tmp/import-config" XDG_DATA_HOME="$tmp/import-data" OC_BIN_DIR="$tmp/import-bin" "$OCP" import "$profile_archive"
assert_file_contains "$import_home/.opencode-profiles/alpha/opencode.json" "profile config"
assert_file_contains "$import_home/.local/share/alpha-extra/data.txt" "extra"
assert_file_contains "$import_home/tools/nested-extra/data.txt" "nested extra"

HOME="$import_home" XDG_CONFIG_HOME="$tmp/import-config" XDG_DATA_HOME="$tmp/import-data" OC_BIN_DIR="$tmp/import-bin" "$OCP" import -f "$global_archive"
assert_file_contains "$import_home/.config/opencode/opencode.json" "global config"
assert_file_contains "$import_home/.local/share/global-extra/data.txt" "global extra"

import_all_home="$tmp/import-all-home"
mkdir -p "$import_all_home"
HOME="$import_all_home" XDG_CONFIG_HOME="$tmp/import-all-config" XDG_DATA_HOME="$tmp/import-all-data" OC_BIN_DIR="$tmp/import-all-bin" "$OCP" import -f "$all_archive"
assert_file_contains "$import_all_home/.opencode-profiles/alpha/opencode.json" "profile config"
assert_file_contains "$import_all_home/.config/opencode/opencode.json" "global config"
assert_file_contains "$import_all_home/.local/share/alpha-extra/data.txt" "extra"
assert_file_contains "$import_all_home/tools/nested-extra/data.txt" "nested extra"
assert_file_contains "$import_all_home/.local/share/global-extra/data.txt" "global extra"

import_skip_home="$tmp/import-skip-home"
mkdir -p "$import_skip_home/.local/share/alpha-extra" "$import_skip_home/.local/share/global-extra"
printf 'existing alpha external\n' > "$import_skip_home/.local/share/alpha-extra/data.txt"
printf 'existing global external\n' > "$import_skip_home/.local/share/global-extra/data.txt"
HOME="$import_skip_home" XDG_CONFIG_HOME="$tmp/import-skip-config" XDG_DATA_HOME="$tmp/import-skip-data" OC_BIN_DIR="$tmp/import-skip-bin" "$OCP" import --skip-existing "$profile_archive"
assert_file_contains "$import_skip_home/.local/share/alpha-extra/data.txt" "existing alpha external"
HOME="$import_skip_home" XDG_CONFIG_HOME="$tmp/import-skip-config" XDG_DATA_HOME="$tmp/import-skip-data" OC_BIN_DIR="$tmp/import-skip-bin" "$OCP" external list alpha > "$tmp/import-skip-profile-external-list"
assert_file_contains "$tmp/import-skip-profile-external-list" "$import_skip_home/.local/share/alpha-extra"
assert_file_not_contains "$tmp/import-skip-profile-external-list" "$HOME/.local/share/alpha-extra"

HOME="$import_skip_home" XDG_CONFIG_HOME="$tmp/import-skip-config" XDG_DATA_HOME="$tmp/import-skip-data" OC_BIN_DIR="$tmp/import-skip-bin" "$OCP" import --skip-existing "$global_archive"
assert_file_contains "$import_skip_home/.local/share/global-extra/data.txt" "existing global external"
HOME="$import_skip_home" XDG_CONFIG_HOME="$tmp/import-skip-config" XDG_DATA_HOME="$tmp/import-skip-data" OC_BIN_DIR="$tmp/import-skip-bin" "$OCP" external list -g > "$tmp/import-skip-global-external-list"
assert_file_contains "$tmp/import-skip-global-external-list" "$import_skip_home/.local/share/global-extra"
assert_file_not_contains "$tmp/import-skip-global-external-list" "$HOME/.local/share/global-extra"

echo "phase3 migration tests passed"
