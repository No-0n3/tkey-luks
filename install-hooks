#!/usr/bin/env sh
# Install git hooks for this repository

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HOOKS_DIR="$SCRIPT_DIR/.githooks"
GIT_HOOKS_DIR="$SCRIPT_DIR/.git/hooks"

echo "Installing git hooks..."

# Check if .githooks directory exists
if [ ! -d "$HOOKS_DIR" ]; then
    echo "Error: .githooks directory not found"
    exit 1
fi

# Create .git/hooks directory if it doesn't exist
mkdir -p "$GIT_HOOKS_DIR"

# Install commit-msg hook
if [ -f "$HOOKS_DIR/commit-msg" ]; then
    cp "$HOOKS_DIR/commit-msg" "$GIT_HOOKS_DIR/commit-msg"
    chmod +x "$GIT_HOOKS_DIR/commit-msg"
    echo "✓ Installed commit-msg hook"
else
    echo "Warning: commit-msg hook not found in .githooks/"
fi

echo ""
echo "Git hooks installed successfully!"
echo ""
echo "The commit-msg hook will now validate your commit messages"
echo "against the conventional commits format."
echo ""
echo "Example valid commit messages:"
echo "  feat: add new feature"
echo "  fix(client): resolve connection issue"
echo "  docs: update installation guide"
echo ""
