#!/bin/bash
set -e

# Run mix format
# Check mode: exit 1 if any files need formatting
# Fix mode: apply formatting changes

MODE="${1:-check}"

if [[ "$MODE" == "fix" ]]; then
    mix format
else
    mix format --check-formatted
fi
