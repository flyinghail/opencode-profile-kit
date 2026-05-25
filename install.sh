#!/usr/bin/env bash
set -euo pipefail

REPO_RAW_URL="${REPO_RAW_URL:-https://raw.githubusercontent.com/flyinghail/opencode-profile-kit/main}"
XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
BIN_DIR="${BIN_DIR:-$HOME/.local/bin}"
INSTALL_DIR="${INSTALL_DIR:-$XDG_DATA_HOME/opencode-profile-kit/bin}"
CLI_NAME="${CLI_NAME:-ocp}"

download_file() {
  local url="$1"
  local output="$2"

  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$url" -o "$output"
    return
  fi

  if command -v wget >/dev/null 2>&1; then
    wget -qO "$output" "$url"
    return
  fi

  cat >&2 <<'EOF'
error: curl or wget is required

Install one of them first:

  Ubuntu/Debian:
    sudo apt update && sudo apt install -y curl

  macOS:
    brew install curl

  Arch:
    sudo pacman -S curl

  Fedora:
    sudo dnf install curl
EOF

  exit 1
}

mkdir -p "$INSTALL_DIR" "$BIN_DIR"

download_file "$REPO_RAW_URL/bin/ocp" "$INSTALL_DIR/ocp"

chmod +x "$INSTALL_DIR/ocp"
ln -sfn "$INSTALL_DIR/ocp" "$BIN_DIR/$CLI_NAME"

echo "installed: $BIN_DIR/$CLI_NAME"
echo "source:    $INSTALL_DIR/ocp"
echo ""
echo "Make sure $BIN_DIR is in PATH."
echo "Run '$CLI_NAME completion bash --install' or '$CLI_NAME completion zsh --install' to install completion manually."
