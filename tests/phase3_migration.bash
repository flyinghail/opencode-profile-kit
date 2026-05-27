#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OCP="$ROOT/bin/ocp"

fail() { echo "test failure: $*" >&2; exit 1; }
assert_file_contains() { grep -Fq "$2" "$1" || fail "expected $1 to contain: $2"; }
assert_tar_contains() { tar -tzf "$1" | grep -Fxq "$2" || fail "expected archive $1 to contain: $2"; }

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
"$OCP" external list alpha > "$tmp/external-list"
assert_file_contains "$tmp/external-list" "$HOME/.local/share/alpha-extra"

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

HOME="$import_home" XDG_CONFIG_HOME="$tmp/import-config" XDG_DATA_HOME="$tmp/import-data" OC_BIN_DIR="$tmp/import-bin" "$OCP" import -f "$global_archive"
assert_file_contains "$import_home/.config/opencode/opencode.json" "global config"
assert_file_contains "$import_home/.local/share/global-extra/data.txt" "global extra"

import_all_home="$tmp/import-all-home"
mkdir -p "$import_all_home"
HOME="$import_all_home" XDG_CONFIG_HOME="$tmp/import-all-config" XDG_DATA_HOME="$tmp/import-all-data" OC_BIN_DIR="$tmp/import-all-bin" "$OCP" import -f "$all_archive"
assert_file_contains "$import_all_home/.opencode-profiles/alpha/opencode.json" "profile config"
assert_file_contains "$import_all_home/.config/opencode/opencode.json" "global config"
assert_file_contains "$import_all_home/.local/share/alpha-extra/data.txt" "extra"
assert_file_contains "$import_all_home/.local/share/global-extra/data.txt" "global extra"

echo "phase3 migration tests passed"
