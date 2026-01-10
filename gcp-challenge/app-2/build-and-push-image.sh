#!/bin/bash

set -e

SUBSCRIBER_APP_NAME="subscriber-app"
REGION="us-central1"

# Expect this to be set in the environment
: "${PROJECT_ID:?Environment variable PROJECT_ID must be set}"

export REGISTRY="us-central1-docker.pkg.dev"
export REPO="apps"
export APP_NAME="subscriber-app"
export TIMESTAMP=$(date +%Y%m%d-%H%M%S)
export IMAGE="${REGISTRY}/${PROJECT_ID}/${REPO}/${APP_NAME}:${TIMESTAMP}"

# Build and push the container image
echo "Building container image..."
docker build -t ${IMAGE} .
echo "Pushing container image..."
docker push ${IMAGE}

echo ""
echo "Image built and pushed successfully!"
echo "Full image reference with timestamp: ${IMAGE}"
