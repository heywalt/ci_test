#!/bin/bash
set -e

# Run dialyzer for static type analysis
# Pass --plt to only build the PLT cache without running analysis

if [[ "${1:-}" == "--plt" ]]; then
    mix dialyzer --plt
else
    mix dialyzer
fi
