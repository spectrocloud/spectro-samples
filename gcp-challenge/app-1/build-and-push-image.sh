#!/bin/bash

set -e

# Builds and pushes the image using the "latest" tag. Assumes the user already
# has Docker and gcloud installed, with gcloud authenticated, and assumes there
# is an Artifact Registry repository already created called "apps" in the
# us-central1 region.

# Expect this to be set in the environment
: "${PROJECT_ID:?Environment variable PROJECT_ID must be set}"

gcloud config set project ${PROJECT_ID}
gcloud auth configure-docker us-central1-docker.pkg.dev --quiet

export REGISTRY="us-central1-docker.pkg.dev"
export REPO="apps"
export APP_NAME="publisher-app"
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
