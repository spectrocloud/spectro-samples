#!/bin/bash

# Require first arg
if [ -z "$1" ]; then
    echo "Usage: $0 <randomValue>"
    exit 1
fi

random_value=$1

echo -n "$random_value" | xargs -I {} curl -X POST http://localhost:3001/pubsub \
  -H "Content-Type: application/json" \
  -d '{
    "message": {
      "data": "{}",
      "messageId": "test-123"
    },
    "subscription": "test-subscription"
  }'