#!/usr/bin/env bash

set -e

function create_collection {
  local collection=${1}
  local schema_file="typesense/${collection}-schema.json"

  echo "Creating ${collection} collection..."

  curl -X POST \
    -H "Content-Type: application/json" \
    -H "X-TYPESENSE-API-KEY: localdevapikey" \
    -d "@${schema_file}" \
    "http://localhost:8108/collections"

  echo ""
  echo ""
}

docker compose up -d --wait typesense

create_collection "contacts"
create_collection "notes"
