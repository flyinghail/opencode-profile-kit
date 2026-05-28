#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OCP="$ROOT/bin/ocp"
export PATH="$ROOT/bin:$PATH"

fail() { echo "test failure: $*" >&2; exit 1; }
assert_file_contains() { grep -Fq "$2" "$1" || fail "expected $1 to contain: $2"; }

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

export HOME="$tmp/home"
export XDG_CONFIG_HOME="$tmp/config"
export XDG_DATA_HOME="$tmp/data"
export OC_BIN_DIR="$tmp/bin"
export EDITOR=true
mkdir -p "$HOME" "$XDG_CONFIG_HOME" "$XDG_DATA_HOME" "$OC_BIN_DIR"

"$OCP" new alpha >/dev/null
alpha_dir="$HOME/.opencode-profiles/alpha"

"$OCP" completion bash > "$tmp/ocp.bash-completion"
completion_output="$(bash -c 'source "$1"; COMP_WORDS=(ocp upgrade ""); COMP_CWORD=2; _ocp_completion; printf "%s\n" "${COMPREPLY[@]}"' _ "$tmp/ocp.bash-completion")"
grep -Fxq 'init' <<< "$completion_output" || fail "upgrade completion did not include init"
grep -Fxq 'edit' <<< "$completion_output" || fail "upgrade completion did not include edit"
grep -Fxq 'show' <<< "$completion_output" || fail "upgrade completion did not include show"
grep -Fxq 'run' <<< "$completion_output" || fail "upgrade completion did not include run"
grep -Fxq -- '-g' <<< "$completion_output" || fail "upgrade completion did not include -g"
grep -Fxq -- '--global' <<< "$completion_output" || fail "upgrade completion did not include --global"
grep -Fxq 'alpha' <<< "$completion_output" || fail "upgrade completion did not include profile names"

cat > "$alpha_dir/.ocp-recipes" <<'SCRIPT'
rewrite-paths=false
printf '%s\n' "$OCP_PROFILE" > profile-name.txt
printf '%s\n' "$OPENCODE_CONFIG_DIR" > config-dir.txt
printf '%s\n' "$OCP_PROFILE_DIR" > profile-dir.txt
printf '%s\n' "$OCP_GLOBAL_DIR" > global-dir.txt
printf '%s\n' "$PWD" > cwd.txt
SCRIPT

"$OCP" upgrade alpha
assert_file_contains "$alpha_dir/profile-name.txt" "alpha"
assert_file_contains "$alpha_dir/config-dir.txt" "$alpha_dir"
assert_file_contains "$alpha_dir/profile-dir.txt" "$alpha_dir"
assert_file_contains "$alpha_dir/global-dir.txt" "$HOME/.config/opencode"
assert_file_contains "$alpha_dir/cwd.txt" "$alpha_dir"

cat > "$alpha_dir/.ocp-recipes" <<'SCRIPT'
rewrite-paths=true
mkdir -p agents
printf '%s\n' "$HOME/.config/opencode/agents/tool.md" > agents/tool.md
SCRIPT

"$OCP" upgrade alpha
assert_file_contains "$alpha_dir/agents/tool.md" "$alpha_dir/agents/tool.md"

cat > "$alpha_dir/.ocp-recipes" <<'SCRIPT'
rewrite-paths=true
false
SCRIPT

if "$OCP" upgrade alpha >/dev/null 2>&1; then
  fail "upgrade failure script unexpectedly passed"
fi

"$OCP" upgrade show alpha > "$tmp/show-profile"
assert_file_contains "$tmp/show-profile" "rewrite-paths=true"

if "$OCP" upgrade init alpha >/dev/null 2>&1; then
  fail "upgrade init unexpectedly overwrote existing recipe"
fi
assert_file_contains "$alpha_dir/.ocp-recipes" "rewrite-paths=true"

printf 'n\n\n' | "$OCP" upgrade init --force alpha >/dev/null
assert_file_contains "$alpha_dir/.ocp-recipes" "rewrite-paths=false"

global_recipe="$XDG_CONFIG_HOME/opencode-profile-kit/global/.ocp-recipes"
mkdir -p "$(dirname "$global_recipe")"
cat > "$global_recipe" <<'SCRIPT'
printf '%s\n' "$OCP_TARGET" > target.txt
printf '%s\n' "$OPENCODE_CONFIG_DIR" > config-dir.txt
printf '%s\n' "$OCP_GLOBAL_DIR" > global-dir.txt
SCRIPT

"$OCP" upgrade -g
global_dir="$HOME/.config/opencode"
assert_file_contains "$global_dir/target.txt" "global"
assert_file_contains "$global_dir/config-dir.txt" "$global_dir"
assert_file_contains "$global_dir/global-dir.txt" "$global_dir"

cat > "$global_recipe" <<'SCRIPT'
rewrite-paths=true
echo bad
SCRIPT

if "$OCP" upgrade -g >/dev/null 2>&1; then
  fail "global recipe with rewrite-paths=true unexpectedly passed"
fi

echo "phase2 upgrade tests passed"
