#!/bin/bash
# Build script for Dart LSP

set -e

echo "🔧 Building Dart LSP..."

# Get script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

# Install dependencies
echo "📦 Installing dependencies..."
dart pub get

# Compile MCP server
echo "🏗️  Compiling MCP server..."
dart compile exe bin/mcp_server.dart -o bin/dart-lsp-mcp

# Compile LSP server (optional, for standalone use)
echo "🏗️  Compiling LSP server..."
dart compile exe bin/server.dart -o bin/dart-lsp

# Make executables
chmod +x bin/dart-lsp-mcp
chmod +x bin/dart-lsp

echo ""
echo "✅ Build complete!"
echo ""
echo "Executables created:"
echo "  - bin/dart-lsp-mcp    (MCP server for Claude Code)"
echo "  - bin/dart-lsp (Standalone LSP server)"
echo ""
echo "============================================="
echo "Installation Options:"
echo "============================================="
echo ""
echo "Option A: Claude Code Plugin (Recommended)"
echo "  1. Run: ./install-plugin.sh"
echo "  2. Run: claude plugin install $(pwd)"
echo "  → Provides real-time diagnostics via LSP"
echo ""
echo "Option B: MCP Server"
echo "  1. Run: ./install-mcp.sh"
echo "  2. Restart Claude Code"
echo "  → Provides explicit tool calls (dart_analyze, etc.)"
echo ""
echo "You can install both for maximum capability."
