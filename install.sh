#!/usr/bin/env bash
set -euo pipefail

REPO_URL="${REPO_URL:-https://github.com/flyinghail/opencode-profile-kit.git}"
INSTALL_DIR="${INSTALL_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/opencode-profile-kit}"
BIN_DIR="${BIN_DIR:-$HOME/.local/bin}"
CLI_NAME="${CLI_NAME:-ocp}"

mkdir -p "$BIN_DIR"
mkdir -p "$(dirname "$INSTALL_DIR")"

if [[ -d "$INSTALL_DIR/.git" ]]; then
  git -C "$INSTALL_DIR" pull --ff-only
else
  rm -rf "$INSTALL_DIR"
  git clone "$REPO_URL" "$INSTALL_DIR"
fi

chmod +x "$INSTALL_DIR/bin/ocp"
ln -sfn "$INSTALL_DIR/bin/ocp" "$BIN_DIR/$CLI_NAME"

echo "installed: $BIN_DIR/$CLI_NAME"
echo "source:    $INSTALL_DIR/bin/ocp"
echo ""
echo "Make sure $BIN_DIR is in PATH."
echo "Run '$CLI_NAME completion bash $CLI_NAME' or '$CLI_NAME completion zsh $CLI_NAME' to install completion manually."
