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
mkdir -p "$HOME" "$XDG_CONFIG_HOME" "$XDG_DATA_HOME" "$OC_BIN_DIR" "$tmp/fake-bin"

"$OCP" new alpha >/dev/null
alpha_dir="$HOME/.opencode-profiles/alpha"

"$OCP" env set alpha OCP_TEST_FLAG=enabled >/dev/null
"$OCP" env set alpha OCP_TEST_SPACED='hello world' >/dev/null
"$OCP" env list alpha > "$tmp/env-list"
assert_file_contains "$tmp/env-list" 'OCP_TEST_FLAG=enabled'
assert_file_contains "$tmp/env-list" 'OCP_TEST_SPACED=hello world'

"$OCP" env alpha > "$tmp/env-export"
assert_file_contains "$tmp/env-export" 'export OCP_TEST_FLAG=enabled'
assert_file_contains "$tmp/env-export" 'export OPENCODE_CONFIG_DIR='

"$OCP" exec alpha -- bash -c 'printf "%s\n" "$OCP_TEST_FLAG" > "$1"; printf "%s\n" "$OPENCODE_CONFIG_DIR" > "$2"' _ "$tmp/exec-flag" "$tmp/exec-dir"
assert_eq "$(cat "$tmp/exec-flag")" "enabled" "exec preset env"
assert_eq "$(cat "$tmp/exec-dir")" "$alpha_dir" "exec OPENCODE_CONFIG_DIR"

shell_probe="$tmp/shell-probe.sh"
cat > "$shell_probe" <<'SCRIPT'
#!/usr/bin/env bash
printf '%s\n' "$OCP_TEST_SPACED" > "$SHELL_PRESET_OUT"
printf '%s\n' "$OPENCODE_CONFIG_DIR" > "$SHELL_CONFIG_OUT"
SCRIPT
chmod +x "$shell_probe"
SHELL_PRESET_OUT="$tmp/shell-preset" SHELL_CONFIG_OUT="$tmp/shell-config" SHELL="$shell_probe" "$OCP" shell alpha
assert_eq "$(cat "$tmp/shell-preset")" "hello world" "shell preset env"
assert_eq "$(cat "$tmp/shell-config")" "$alpha_dir" "shell OPENCODE_CONFIG_DIR"

cat > "$tmp/fake-bin/opencode" <<'SCRIPT'
#!/usr/bin/env bash
printf '%s\n' "$OCP_TEST_FLAG" > "$RUN_PRESET_OUT"
printf '%s\n' "$OPENCODE_CONFIG_DIR" > "$RUN_CONFIG_OUT"
SCRIPT
chmod +x "$tmp/fake-bin/opencode"
PATH="$tmp/fake-bin:$PATH" RUN_PRESET_OUT="$tmp/run-preset" RUN_CONFIG_OUT="$tmp/run-config" "$OCP" run alpha
assert_eq "$(cat "$tmp/run-preset")" "enabled" "run preset env"
assert_eq "$(cat "$tmp/run-config")" "$alpha_dir" "run OPENCODE_CONFIG_DIR"

printf 'OPENCODE_CONFIG_DIR=/tmp/bad\n' >> "$alpha_dir/.ocp-env"
"$OCP" exec alpha -- bash -c 'printf "%s\n" "$OPENCODE_CONFIG_DIR"' > "$tmp/reserved-dir"
assert_eq "$(cat "$tmp/reserved-dir")" "$alpha_dir" "reserved OPENCODE_CONFIG_DIR override"

if "$OCP" env set alpha 'BAD-NAME=value' >/dev/null 2>&1; then
  fail "invalid env key unexpectedly succeeded"
fi

"$OCP" env remove alpha OCP_TEST_FLAG >/dev/null
"$OCP" env list alpha > "$tmp/env-list-after-remove"
if grep -Fq 'OCP_TEST_FLAG=' "$tmp/env-list-after-remove"; then
  fail "env remove left OCP_TEST_FLAG"
fi

echo "env preset tests passed"
