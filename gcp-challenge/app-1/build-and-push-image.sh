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

# Build and push the container image
echo "Building container image..."
docker build -t ${REGISTRY}/${PROJECT_ID}/${REPO}/${APP_NAME} .
echo "Pushing container image..."
docker push ${REGISTRY}/${PROJECT_ID}/${REPO}/${APP_NAME}
