#!/bin/bash
set -e

SKILL_NAME="parallel-dev"
SKILL_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/skills/${SKILL_NAME}"

echo "======================================="
echo "  Parallel-Dev Skill Installer"
echo "======================================="
echo ""

# Detect install source
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Check if running from git clone or standalone
if [ -f "$SCRIPT_DIR/SKILL.md" ]; then
    SOURCE_DIR="$SCRIPT_DIR"
else
    echo "Error: Cannot find SKILL.md. Please run this script from the cloned repository."
    exit 1
fi

# Create skill directory
echo "Creating skill directory: $SKILL_DIR"
mkdir -p "$SKILL_DIR"

# Copy skill files
echo "Copying skill files..."
cp "$SOURCE_DIR/SKILL.md" "$SKILL_DIR/"
cp "$SOURCE_DIR/auto-req.md" "$SKILL_DIR/"
cp "$SOURCE_DIR/auto-dev.md" "$SKILL_DIR/"
cp "$SOURCE_DIR/auto-test.md" "$SKILL_DIR/"
cp "$SOURCE_DIR/auto-triage.md" "$SKILL_DIR/"

echo ""
echo "Done! Skill installed to: $SKILL_DIR"
echo ""
echo "Files installed:"
ls -la "$SKILL_DIR"
echo ""
echo "Next steps:"
echo "  1. Restart Claude Code or run /reload-plugins (if supported)"
echo "  2. Invoke with: /parallel-dev <your task>"
echo ""
echo "Example:"
echo "  /parallel-dev \"Implement user registration with email verification\""
