#!/bin/bash
set -e

# Run all checks in sequence, stopping on first failure
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== Running fmt check ==="
"$SCRIPT_DIR/checks/fmt.sh"

echo "=== Running compile check ==="
"$SCRIPT_DIR/checks/compile.sh"

echo "=== Running credo check ==="
"$SCRIPT_DIR/checks/credo.sh"

echo "=== Running tests ==="
"$SCRIPT_DIR/checks/test.sh"

echo "=== Running dialyzer ==="
"$SCRIPT_DIR/checks/dialyzer.sh"

echo "=== All checks passed ==="
