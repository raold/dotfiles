#!/bin/bash
# Mac M4 Dev Environment Setup for Claude Code
# Run: bash ~/setup_mac_dev_tools.sh
#
# This script installs development tools that complement Claude Code's
# allowed commands. GNU tools are installed with 'g' prefix (gsed, ggrep, etc.)
# to keep Mac's BSD defaults intact.

set -e

echo "=== Mac M4 Dev Environment Setup for Claude Code ==="
echo ""

# Check for Homebrew
if ! command -v brew &> /dev/null; then
    echo "Homebrew not found. Installing..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

echo "Updating Homebrew..."
brew update

echo ""
echo "=== Installing GNU Core Utilities ==="
echo "These will be available with 'g' prefix (gsed, ggrep, gawk, gtar)"
brew install coreutils gnu-sed gnu-tar grep gawk || true

echo ""
echo "=== Installing Modern CLI Tools ==="
# tree - Directory visualization
# htop - Better top/process viewer
# jq - JSON processor (essential for API work)
# ripgrep - Fast grep alternative (rg)
# fd - Fast find alternative
# bat - Better cat with syntax highlighting
# eza - Better ls (formerly exa)
# fzf - Fuzzy finder
# watch - Run command periodically
# tldr - Simplified man pages
brew install tree htop jq ripgrep fd bat eza fzf watch tldr || true

echo ""
echo "=== Installing Development Tools ==="
# gh - GitHub CLI
# uv - Fast Python package manager
brew install gh uv || true

echo ""
echo "=== Verifying Installation ==="
echo ""
echo "Checking installed tools:"
echo -n "  jq: " && (jq --version 2>/dev/null || echo "NOT INSTALLED")
echo -n "  ripgrep: " && (rg --version 2>/dev/null | head -1 || echo "NOT INSTALLED")
echo -n "  fd: " && (fd --version 2>/dev/null || echo "NOT INSTALLED")
echo -n "  bat: " && (bat --version 2>/dev/null || echo "NOT INSTALLED")
echo -n "  eza: " && (eza --version 2>/dev/null || echo "NOT INSTALLED")
echo -n "  fzf: " && (fzf --version 2>/dev/null || echo "NOT INSTALLED")
echo -n "  htop: " && (htop --version 2>/dev/null | head -1 || echo "NOT INSTALLED")
echo -n "  tree: " && (tree --version 2>/dev/null || echo "NOT INSTALLED")
echo -n "  gh: " && (gh --version 2>/dev/null | head -1 || echo "NOT INSTALLED")
echo -n "  uv: " && (uv --version 2>/dev/null || echo "NOT INSTALLED")
echo ""
echo "GNU tools (g-prefixed):"
echo -n "  gsed: " && (gsed --version 2>/dev/null | head -1 || echo "NOT INSTALLED")
echo -n "  ggrep: " && (ggrep --version 2>/dev/null | head -1 || echo "NOT INSTALLED")
echo -n "  gawk: " && (gawk --version 2>/dev/null | head -1 || echo "NOT INSTALLED")

echo ""
echo "=== Setup Complete ==="
echo ""
echo "Tool aliases you might want to add to ~/.zshrc:"
echo '  alias cat="bat"'
echo '  alias ls="eza"'
echo '  alias find="fd"'
echo '  alias grep="rg"'
echo ""
echo "Note: These are optional - Mac defaults work fine with Claude Code."
