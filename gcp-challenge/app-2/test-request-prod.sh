#!/bin/bash

# Expect this to be set in the environment
: "${PROJECT_NUMBER:?Environment variable PROJECT_NUMBER must be set}"

echo -n "Hello World" | base64 | xargs -I {} curl -X POST https://subscriber-app-${PROJECT_NUMBER}.us-central1.run.app/pubsub \
  -H "Content-Type: application/json" \
  -d '{
    "message": {
      "data": "{}",
      "messageId": "test-123"
    },
    "subscription": "test-subscription"
  }'
