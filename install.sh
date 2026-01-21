#!/bin/bash
# Remote installer for Dart LSP MCP Server
# Usage: curl -fsSL https://raw.githubusercontent.com/coco-de/dart-lsp/main/install.sh | bash

set -e

REPO="coco-de/dart-lsp"
INSTALL_DIR="$HOME/.local/bin"
BINARY_NAME="dart-lsp-mcp"

echo "🚀 Dart LSP MCP Server Installer"
echo "================================="
echo ""

# Detect OS and architecture
OS="$(uname -s)"
ARCH="$(uname -m)"

case "$OS" in
    Darwin)
        case "$ARCH" in
            arm64)
                ARTIFACT="dart-lsp-macos-arm64"
                ;;
            x86_64)
                ARTIFACT="dart-lsp-macos-x64"
                ;;
            *)
                echo "❌ Unsupported architecture: $ARCH"
                exit 1
                ;;
        esac
        CONFIG_DIR="$HOME/Library/Application Support/Claude"
        ;;
    Linux)
        case "$ARCH" in
            x86_64)
                ARTIFACT="dart-lsp-linux-x64"
                ;;
            *)
                echo "❌ Unsupported architecture: $ARCH"
                exit 1
                ;;
        esac
        CONFIG_DIR="$HOME/.config/claude"
        ;;
    *)
        echo "❌ Unsupported OS: $OS"
        exit 1
        ;;
esac

echo "📍 Detected: $OS ($ARCH)"
echo "📦 Artifact: $ARTIFACT"
echo ""

# Get latest release URL
echo "🔍 Fetching latest release..."
RELEASE_URL=$(curl -sL "https://api.github.com/repos/$REPO/releases/latest" | grep "browser_download_url.*$ARTIFACT" | cut -d '"' -f 4)

if [ -z "$RELEASE_URL" ]; then
    echo "❌ Could not find release for $ARTIFACT"
    echo "   Please check https://github.com/$REPO/releases"
    exit 1
fi

echo "📥 Downloading from: $RELEASE_URL"

# Create install directory
mkdir -p "$INSTALL_DIR"

# Download binary
curl -sL "$RELEASE_URL" -o "$INSTALL_DIR/$BINARY_NAME"
chmod +x "$INSTALL_DIR/$BINARY_NAME"

echo "✅ Binary installed to: $INSTALL_DIR/$BINARY_NAME"

# Check PATH
if [[ ":$PATH:" != *":$INSTALL_DIR:"* ]]; then
    echo ""
    echo "⚠️  $INSTALL_DIR is not in PATH"
    echo "   Add to your shell profile:"
    echo ""
    echo "   export PATH=\"\$PATH:$INSTALL_DIR\""
    echo ""
fi

# Configure Claude
echo ""
echo "🔧 Configuring Claude Code..."

mkdir -p "$CONFIG_DIR"
CONFIG_FILE="$CONFIG_DIR/claude_desktop_config.json"
BINARY_PATH="$INSTALL_DIR/$BINARY_NAME"

python3 << PYTHON
import json
import os

config_file = "$CONFIG_FILE"
binary_path = "$BINARY_PATH"

# Load or create config
try:
    with open(config_file, 'r') as f:
        config = json.load(f)
except (FileNotFoundError, json.JSONDecodeError):
    config = {}

# Ensure mcpServers exists
if 'mcpServers' not in config:
    config['mcpServers'] = {}

# Add/update dart-lsp
config['mcpServers']['dart-lsp'] = {
    'command': binary_path,
    'args': [],
    'env': {}
}

# Save config
with open(config_file, 'w') as f:
    json.dump(config, f, indent=2)

print(f"✅ Configuration saved to: {config_file}")
PYTHON

echo ""
echo "🎉 Installation complete!"
echo ""
echo "Available MCP Tools:"
echo "  • dart_analyze      - Check code for errors/warnings"
echo "  • dart_complete     - Get code completions"
echo "  • dart_hover        - Get documentation at position"
echo "  • dart_definition   - Go to definition"
echo "  • dart_format       - Format code"
echo "  • dart_symbols      - Get document outline"
echo "  • dart_code_actions - Get quick fixes"
echo "  • dart_add_workspace - Add workspace for analysis"
echo ""
echo "⚠️  Restart Claude Code to apply changes."
