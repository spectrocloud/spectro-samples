#!/bin/bash

# Exit on error
set -e

# Expect this to be set in the environment
: "${PROJECT_ID:?Environment variable PROJECT_ID must be set}"

# Set variables
APP_NAME="publisher-app"
CLUSTER_NAME="${APP_NAME}-cluster"
ZONE="us-central1-a"

# Delete the GKE cluster
echo "Deleting GKE cluster ${CLUSTER_NAME}..."
gcloud container clusters delete ${CLUSTER_NAME} \
    --zone=${ZONE} \
    --quiet

# Delete the IAM service account
echo "Deleting IAM service account ${APP_NAME}@${PROJECT_ID}.iam.gserviceaccount.com..."
gcloud iam service-accounts delete \
    ${APP_NAME}@${PROJECT_ID}.iam.gserviceaccount.com \
    --quiet

echo "Teardown complete!"
