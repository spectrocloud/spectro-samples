#!/bin/bash

set -e

SUBSCRIBER_APP_NAME="subscriber-app"
REGION="us-central1"

# Expect this to be set in the environment
: "${PROJECT_ID:?Environment variable PROJECT_ID must be set}"

export REGISTRY="us-central1-docker.pkg.dev"
export REPO="apps"
export APP_NAME="subscriber-app"

docker build -t ${REGISTRY}/${PROJECT_ID}/${REPO}/${APP_NAME} .
docker push ${REGISTRY}/${PROJECT_ID}/${REPO}/${APP_NAME}

gcloud run deploy ${APP_NAME} \
    --image ${REGISTRY}/${PROJECT_ID}/${REPO}/${APP_NAME} \
    --platform managed \
    --region ${REGION} \
    --allow-unauthenticated
