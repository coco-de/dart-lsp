#!/bin/bash
# Install Dart LSP MCP Server for Claude Code

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
MCP_BINARY="$SCRIPT_DIR/bin/dart-lsp-mcp"

# Check if binary exists
if [ ! -f "$MCP_BINARY" ]; then
    echo "❌ MCP server binary not found. Run ./build.sh first."
    exit 1
fi

echo "🚀 Installing Dart LSP MCP Server for Claude Code..."
echo ""

# Detect OS
OS="$(uname -s)"
case "$OS" in
    Darwin)
        CONFIG_DIR="$HOME/Library/Application Support/Claude"
        ;;
    Linux)
        CONFIG_DIR="$HOME/.config/claude"
        ;;
    *)
        echo "❌ Unsupported OS: $OS"
        exit 1
        ;;
esac

# Create config directory if needed
mkdir -p "$CONFIG_DIR"

CONFIG_FILE="$CONFIG_DIR/claude_desktop_config.json"

# MCP configuration to add
MCP_CONFIG=$(cat <<EOF
{
  "mcpServers": {
    "dart-lsp": {
      "command": "$MCP_BINARY",
      "args": [],
      "env": {}
    }
  }
}
EOF
)

# Check if config file exists
if [ -f "$CONFIG_FILE" ]; then
    echo "📝 Existing config found. Backing up..."
    cp "$CONFIG_FILE" "$CONFIG_FILE.backup"
    
    # Check if dart-lsp already configured
    if grep -q "dart-lsp" "$CONFIG_FILE"; then
        echo "⚠️  dart-lsp already configured. Updating..."
        # Use Python to merge JSON (more reliable than jq for complex merges)
        python3 << PYTHON
import json
import sys

config_file = "$CONFIG_FILE"
mcp_binary = "$MCP_BINARY"

try:
    with open(config_file, 'r') as f:
        config = json.load(f)
except:
    config = {}

if 'mcpServers' not in config:
    config['mcpServers'] = {}

config['mcpServers']['dart-lsp'] = {
    'command': mcp_binary,
    'args': [],
    'env': {}
}

with open(config_file, 'w') as f:
    json.dump(config, f, indent=2)

print("✅ Updated dart-lsp configuration")
PYTHON
    else
        # Add to existing config
        python3 << PYTHON
import json

config_file = "$CONFIG_FILE"
mcp_binary = "$MCP_BINARY"

try:
    with open(config_file, 'r') as f:
        config = json.load(f)
except:
    config = {}

if 'mcpServers' not in config:
    config['mcpServers'] = {}

config['mcpServers']['dart-lsp'] = {
    'command': mcp_binary,
    'args': [],
    'env': {}
}

with open(config_file, 'w') as f:
    json.dump(config, f, indent=2)

print("✅ Added dart-lsp to existing configuration")
PYTHON
    fi
else
    # Create new config file
    echo "$MCP_CONFIG" > "$CONFIG_FILE"
    echo "✅ Created new configuration file"
fi

echo ""
echo "📍 Configuration saved to: $CONFIG_FILE"
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
echo "⚠️  Please restart Claude Code to apply changes."
