#!/bin/bash

echo -n "Hello World" | base64 | xargs -I {} curl -X POST http://localhost:3001/pubsub \
  -H "Content-Type: application/json" \
  -d '{
    "message": {
      "data": "{}",
      "messageId": "test-123"
    },
    "subscription": "test-subscription"
  }'
