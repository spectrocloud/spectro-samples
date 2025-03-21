#!/bin/bash

# Expect this to be set in the environment
: "${PROJECT_ID:?Environment variable PROJECT_ID must be set}"

export PORT=3000
export PUBSUB_TOPIC=test-topic
export GOOGLE_APPLICATION_CREDENTIALS="publisher-app.json"

go run main.go
