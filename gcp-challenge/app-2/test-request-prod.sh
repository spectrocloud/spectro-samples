#!/bin/bash

echo -n "Hello World" | base64 | xargs -I {} curl -X POST https://subscriber-app-194975296395.us-central1.run.app/pubsub \
  -H "Content-Type: application/json" \
  -d '{
    "message": {
      "data": "{}",
      "messageId": "test-123"
    },
    "subscription": "test-subscription"
  }'
