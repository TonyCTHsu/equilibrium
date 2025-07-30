#!/bin/bash

# Script to check for trailing whitespace in code files
# Usage: ./scripts/check-whitespace.sh [--fix]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# File patterns to check
FILE_PATTERNS=(
    "*.rb"
    "*.sh"
    "*.md"
    "*.yml"
    "*.yaml"
    "*.json"
    "*.js"
    "*.ts"
    "*.css"
    "*.html"
)

# Build find command with file patterns
FIND_PATTERNS=""
for pattern in "${FILE_PATTERNS[@]}"; do
    if [ -n "$FIND_PATTERNS" ]; then
        FIND_PATTERNS="$FIND_PATTERNS -o"
    fi
    FIND_PATTERNS="$FIND_PATTERNS -name \"$pattern\""
done

FIX_MODE=false
if [ "$1" = "--fix" ]; then
    FIX_MODE=true
fi

echo -e "${BLUE}🔍 Checking for trailing whitespace...${NC}"

# Find files with trailing whitespace (exclude vendor and other directories)
WHITESPACE_FILES=$(eval "find . -type f \\( $FIND_PATTERNS \\) -not -path './vendor/*' -not -path './.bundle/*' -not -path './node_modules/*' -not -path './.git/*' -exec grep -l '[[:space:]]$' {} \\; 2>/dev/null" || true)

if [ -n "$WHITESPACE_FILES" ]; then
    echo -e "${RED}❌ Trailing whitespace found in the following files:${NC}"
    echo "$WHITESPACE_FILES" | while read -r file; do
        echo "   $file"
        # Show the actual lines with trailing whitespace
        grep -n '[[:space:]]$' "$file" | head -3 | while read -r line; do
            echo -e "      ${YELLOW}$line${NC}"
        done
        if [ "$(grep -c '[[:space:]]$' "$file")" -gt 3 ]; then
            echo "      ... and more"
        fi
        echo
    done

    if [ "$FIX_MODE" = true ]; then
        echo -e "${BLUE}🔧 Fixing trailing whitespace...${NC}"
        echo "$WHITESPACE_FILES" | while read -r file; do
            # Remove trailing whitespace
            sed -i '' 's/[[:space:]]*$//' "$file"

            # Ensure file ends with newline
            if [ -s "$file" ] && [ "$(tail -c1 "$file")" != "" ]; then
                echo "" >> "$file"
            fi

            echo -e "   ${GREEN}✅ Fixed: $file${NC}"
        done
        echo -e "${GREEN}✨ All files cleaned!${NC}"
        exit 0
    else
        echo -e "${YELLOW}💡 To fix automatically, run:${NC}"
        echo "   $0 --fix"
        echo
        echo -e "${YELLOW}💡 To fix manually, run:${NC}"
        echo "   sed -i '' 's/[[:space:]]*$//' filename"
        exit 1
    fi
else
    echo -e "${GREEN}✅ No trailing whitespace found${NC}"
    exit 0
fi
