
#!/usr/bin/env bash

set -euo pipefail

# Project root: directory containing this script
ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

echo "Setting up project in: $ROOT_DIR"

# Create directories
mkdir -p \
    "$ROOT_DIR/include" \
    "$ROOT_DIR/src" \
    "$ROOT_DIR/tests" \
    "$ROOT_DIR/build"

# Header files
touch \
    "$ROOT_DIR/include/hash_table.h" \
    "$ROOT_DIR/include/protocol.h" \
    "$ROOT_DIR/include/server.h" \
    "$ROOT_DIR/include/persistence.h"

# Source files
touch \
    "$ROOT_DIR/src/main.c" \
    "$ROOT_DIR/src/hash_table.c" \
    "$ROOT_DIR/src/protocol.c" \
    "$ROOT_DIR/src/server.c" \
    "$ROOT_DIR/src/persistence.c"

# Test files
touch \
    "$ROOT_DIR/tests/test_hash_table.c" \
    "$ROOT_DIR/tests/test_protocol.c" \
    "$ROOT_DIR/tests/test_persistence.c"

# Project configuration files
touch \
    "$ROOT_DIR/Makefile" \
    "$ROOT_DIR/.gitignore" \
    "$ROOT_DIR/README.md"

echo
echo "Project structure created successfully!"
echo

# Display the structure
if command -v tree >/dev/null 2>&1; then
    tree -a -I '.git' "$ROOT_DIR"
else
    find "$ROOT_DIR" -maxdepth 2 -not -path '*/.git*' -print | sort
fi
