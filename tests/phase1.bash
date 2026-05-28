#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OCP="$ROOT/bin/ocp"

fail() {
  echo "test failure: $*" >&2
  exit 1
}

assert_file_contains() {
  local file="$1" expected="$2"
  grep -Fq "$expected" "$file" || fail "expected $file to contain: $expected"
}

assert_eq() {
  local actual="$1" expected="$2" label="$3"
  [[ "$actual" == "$expected" ]] || fail "$label: expected '$expected', got '$actual'"
}

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

export HOME="$tmp/home"
export XDG_CONFIG_HOME="$tmp/config"
export XDG_DATA_HOME="$tmp/data"
export OC_BIN_DIR="$tmp/bin"
mkdir -p "$HOME" "$XDG_CONFIG_HOME" "$XDG_DATA_HOME" "$OC_BIN_DIR"

"$OCP" new alpha >/dev/null
alpha_dir="$HOME/.opencode-profiles/alpha"

printf '%s\n' 'echo "$OPENCODE_CONFIG_DIR" > env.out' 'pwd > pwd.out' | "$OCP" exec alpha --stdin
assert_eq "$(cat "$alpha_dir/env.out")" "$alpha_dir" "exec --stdin OPENCODE_CONFIG_DIR"

shell_probe="$tmp/shell-probe.sh"
cat > "$shell_probe" <<'SCRIPT'
#!/usr/bin/env bash
pwd > "$SHELL_PROBE_PWD"
printf '%s\n' "$OPENCODE_CONFIG_DIR" > "$SHELL_PROBE_ENV"
SCRIPT
chmod +x "$shell_probe"
SHELL_PROBE_PWD="$tmp/shell-pwd" SHELL_PROBE_ENV="$tmp/shell-env" SHELL="$shell_probe" "$OCP" shell alpha
assert_eq "$(cat "$tmp/shell-pwd")" "$alpha_dir" "shell cwd"
assert_eq "$(cat "$tmp/shell-env")" "$alpha_dir" "shell OPENCODE_CONFIG_DIR"

"$OCP" bin create alpha oc-alpha >/dev/null
"$OCP" bin list > "$tmp/bin-list-before"
assert_file_contains "$tmp/bin-list-before" $'oc-alpha\talpha\t'
[[ -x "$OC_BIN_DIR/oc-alpha" ]] || fail "bin create did not write an executable launcher"
bash -n "$OC_BIN_DIR/oc-alpha"

mkdir -p "$alpha_dir/agents"
printf 'old path: %s/.config/opencode\nold profile path: %s\n' "$HOME" "$alpha_dir" > "$alpha_dir/agents/example.md"
"$OCP" rename alpha beta > "$tmp/rename-output"
beta_dir="$HOME/.opencode-profiles/beta"
[[ -d "$beta_dir" ]] || fail "renamed profile directory missing"
[[ ! -d "$alpha_dir" ]] || fail "old profile directory still exists"
assert_file_contains "$beta_dir/.ocp-profile.json" '"name": "beta"'
"$OCP" list > "$tmp/profiles-after-rename"
assert_file_contains "$tmp/profiles-after-rename" 'beta'
"$OCP" bin list beta > "$tmp/bin-list-after"
assert_file_contains "$tmp/bin-list-after" $'oc-alpha\tbeta\t'
assert_file_contains "$OC_BIN_DIR/oc-alpha" 'run "beta"'
assert_file_contains "$tmp/rename-output" 'hardcoded path references may remain'

"$OCP" bin repair oc-alpha >/dev/null
assert_file_contains "$OC_BIN_DIR/oc-alpha" 'run "beta"'
"$OCP" bin remove oc-alpha >/dev/null
[[ ! -e "$OC_BIN_DIR/oc-alpha" ]] || fail "bin remove left launcher on disk"
"$OCP" bin list > "$tmp/bin-list-final"
if grep -Fq 'oc-alpha' "$tmp/bin-list-final"; then
  fail "bin remove left bins.tsv entry"
fi

echo "phase1 behavior tests passed"
