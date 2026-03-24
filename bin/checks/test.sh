#!/bin/bash
set -e

# Run tests with early exit on failure
# Defaults to full suite if no arguments provided
# Tests run in transactions that are rolled back, so no DB reset is needed

ARGS="${*}"

if [ -n "$ARGS" ]; then
    mix test --max-failures 5 $ARGS
else
    mix test --max-failures 5
fi
