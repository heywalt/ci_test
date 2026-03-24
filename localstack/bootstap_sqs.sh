#!/usr/bin/env bash

set -euo pipefail

function create_queue {
  awslocal --endpoint-url=http://localhost:4566 sqs create-queue --queue-name $1
}

create_queue "create-contacts"
create_queue "upsert-contacts"
