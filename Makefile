# Dart LSP for Claude Code - Makefile
# Usage: make install

SHELL := /bin/bash
.DEFAULT_GOAL := help

# Directories
PROJECT_DIR := $(shell pwd)
BIN_DIR := $(PROJECT_DIR)/bin
PLUGIN_DIR := $(PROJECT_DIR)/.claude-plugin

# OS Detection
UNAME_S := $(shell uname -s)
ifeq ($(UNAME_S),Darwin)
    INSTALL_DIR := $(HOME)/bin
    CLAUDE_CONFIG_DIR := $(HOME)/Library/Application Support/Claude
    ZED_CONFIG_DIR := $(HOME)/.config/zed
else
    INSTALL_DIR := $(HOME)/.local/bin
    CLAUDE_CONFIG_DIR := $(HOME)/.config/claude
    ZED_CONFIG_DIR := $(HOME)/.config/zed
endif

MARKETPLACE_DIR := $(HOME)/dart-lsp-marketplace

# Binaries
LSP_BINARY := $(BIN_DIR)/dart-lsp
MCP_BINARY := $(BIN_DIR)/dart-lsp-mcp

# Colors
GREEN := \033[0;32m
YELLOW := \033[0;33m
BLUE := \033[0;34m
NC := \033[0m

.PHONY: help build install install-plugin install-mcp install-marketplace install-zed clean uninstall

##@ General

help: ## Show this help
	@awk 'BEGIN {FS = ":.*##"; printf "\n$(BLUE)Dart LSP$(NC) - Installation Makefile\n\nUsage:\n  make $(GREEN)<target>$(NC)\n"} /^[a-zA-Z_0-9-]+:.*?##/ { printf "  $(GREEN)%-18s$(NC) %s\n", $$1, $$2 } /^##@/ { printf "\n$(YELLOW)%s$(NC)\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

##@ Build

build: ## Build LSP and MCP server binaries
	@echo "$(BLUE)🔧 Building Dart LSP...$(NC)"
	@dart pub get
	@echo "$(BLUE)🏗️  Compiling LSP server...$(NC)"
	@dart compile exe bin/server.dart -o $(LSP_BINARY)
	@echo "$(BLUE)🏗️  Compiling MCP server...$(NC)"
	@dart compile exe bin/mcp_server.dart -o $(MCP_BINARY)
	@chmod +x $(LSP_BINARY) $(MCP_BINARY)
	@echo "$(GREEN)✅ Build complete!$(NC)"

##@ Installation

install: build install-binary install-mcp install-marketplace install-claude-plugin ## Full installation (build + plugin + mcp + marketplace)
	@echo ""
	@echo "$(GREEN)🎉 Installation complete!$(NC)"
	@echo ""
	@echo "$(YELLOW)⚠️  Restart Claude Code to apply changes$(NC)"

install-binary: ## Install LSP binary to PATH
	@echo "$(BLUE)📦 Installing binary...$(NC)"
	@mkdir -p "$(INSTALL_DIR)"
	@cp $(LSP_BINARY) "$(INSTALL_DIR)/"
	@chmod +x "$(INSTALL_DIR)/dart-lsp"
	@echo "$(GREEN)✅ Binary installed to $(INSTALL_DIR)/dart-lsp$(NC)"
	@if [[ ":$$PATH:" != *":$(INSTALL_DIR):"* ]]; then \
		echo ""; \
		echo "$(YELLOW)⚠️  Add to PATH:$(NC)"; \
		echo "   echo 'export PATH=\"\$$PATH:$(INSTALL_DIR)\"' >> ~/.zshrc && source ~/.zshrc"; \
	fi

install-mcp: ## Install MCP server configuration
	@echo "$(BLUE)🔌 Installing MCP server...$(NC)"
	@mkdir -p "$(CLAUDE_CONFIG_DIR)"
	@python3 -c "\
import json, os; \
cf='$(CLAUDE_CONFIG_DIR)/claude_desktop_config.json'; \
c=json.load(open(cf)) if os.path.exists(cf) else {}; \
c.setdefault('mcpServers',{})['dart-lsp']={'command':'$(MCP_BINARY)','args':[],'env':{}}; \
json.dump(c,open(cf,'w'),indent=2)"
	@echo "$(GREEN)✅ MCP server configured$(NC)"

install-marketplace: ## Setup local marketplace for Claude Code plugin
	@echo "$(BLUE)📦 Setting up marketplace...$(NC)"
	@mkdir -p "$(MARKETPLACE_DIR)/dart-lsp/.claude-plugin"
	@mkdir -p "$(MARKETPLACE_DIR)/.claude-plugin"
	@cp $(PLUGIN_DIR)/plugin.json "$(MARKETPLACE_DIR)/dart-lsp/.claude-plugin/"
	@echo '{"name":"dart-lsp-local","owner":{"name":"Local","email":"local@localhost"},"plugins":[{"name":"dart-lsp","version":"0.1.0","source":"./dart-lsp","description":"Dart LSP for Claude Code","category":"development","tags":["dart","flutter","lsp"]}]}' > "$(MARKETPLACE_DIR)/.claude-plugin/marketplace.json"
	@echo "$(GREEN)✅ Marketplace created at $(MARKETPLACE_DIR)$(NC)"

install-claude-plugin: ## Register plugin with Claude Code
	@echo "$(BLUE)🔌 Registering Claude Code plugin...$(NC)"
	@claude plugin marketplace add "$(MARKETPLACE_DIR)" 2>/dev/null || true
	@claude plugin install dart-lsp@dart-lsp-local 2>/dev/null || echo "$(YELLOW)⚠️  Run manually: claude plugin install dart-lsp@dart-lsp-local$(NC)"
	@echo "$(GREEN)✅ Plugin registration attempted$(NC)"

install-zed: build install-binary ## Install LSP for Zed editor
	@echo "$(BLUE)🔧 Configuring Zed...$(NC)"
	@mkdir -p "$(ZED_CONFIG_DIR)"
	@if [ -f "$(ZED_CONFIG_DIR)/settings.json" ]; then \
		python3 -c "\
import json; \
f='$(ZED_CONFIG_DIR)/settings.json'; \
c=json.load(open(f)); \
c.setdefault('lsp',{})['dart']={'binary':{'path':'$(INSTALL_DIR)/dart-lsp'}}; \
c.setdefault('languages',{}).setdefault('Dart',{})['language_servers']=['dart','dart-lsp']; \
json.dump(c,open(f,'w'),indent=2)"; \
	else \
		echo '{"lsp":{"dart-lsp":{"binary":{"path":"$(INSTALL_DIR)/dart-lsp"}}},"languages":{"Dart":{"language_servers":["dart-lsp"]}}}' > "$(ZED_CONFIG_DIR)/settings.json"; \
	fi
	@echo "$(GREEN)✅ Zed configured$(NC)"
	@echo "$(YELLOW)⚠️  Restart Zed to apply changes$(NC)"

##@ Cleanup

clean: ## Remove build artifacts
	@echo "$(BLUE)🧹 Cleaning build artifacts...$(NC)"
	@rm -f $(LSP_BINARY) $(MCP_BINARY)
	@rm -rf .dart_tool/
	@echo "$(GREEN)✅ Clean complete$(NC)"

uninstall: ## Remove all installed components
	@echo "$(BLUE)🗑️  Uninstalling...$(NC)"
	@rm -f "$(INSTALL_DIR)/dart-lsp"
	@rm -rf "$(MARKETPLACE_DIR)"
	@claude plugin uninstall dart-lsp@dart-lsp-local 2>/dev/null || true
	@claude plugin marketplace remove dart-lsp-local 2>/dev/null || true
	@echo "$(GREEN)✅ Uninstall complete$(NC)"
	@echo "$(YELLOW)⚠️  MCP config in claude_desktop_config.json not removed (manual cleanup if needed)$(NC)"

##@ Information

info: ## Show installation paths and status
	@echo "$(BLUE)Dart LSP Installation Info$(NC)"
	@echo "=========================="
	@echo "Project:     $(PROJECT_DIR)"
	@echo "Install dir: $(INSTALL_DIR)"
	@echo "Config dir:  $(CLAUDE_CONFIG_DIR)"
	@echo "Marketplace: $(MARKETPLACE_DIR)"
	@echo ""
	@echo "$(YELLOW)Binaries:$(NC)"
	@test -f $(LSP_BINARY) && echo "  ✅ $(LSP_BINARY)" || echo "  ❌ $(LSP_BINARY) (run: make build)"
	@test -f $(MCP_BINARY) && echo "  ✅ $(MCP_BINARY)" || echo "  ❌ $(MCP_BINARY) (run: make build)"
	@echo ""
	@echo "$(YELLOW)Installed:$(NC)"
	@test -f "$(INSTALL_DIR)/dart-lsp" && echo "  ✅ $(INSTALL_DIR)/dart-lsp" || echo "  ❌ $(INSTALL_DIR)/dart-lsp"
	@command -v dart-lsp >/dev/null && echo "  ✅ dart-lsp in PATH" || echo "  ❌ dart-lsp not in PATH"
