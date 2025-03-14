#!/bin/bash

# This script performs steps that only need to be completed once for the project. It excludes steps
# that need to be performed for each deployment, which are handled in the deployment script for each
# app.

set -e

# Expect these to be set in the environment
: "${PROJECT_ID:?Environment variable PROJECT_ID must be set}"
: "${PROJECT_NUMBER:?Environment variable PROJECT_NUMBER must be set}"

export REGION="us-central1"
export SUBSCRIBER_APP_NAME="subscriber-app"
export PUBLISHER_APP_NAME="publisher-app"

# Enable required APIs if they are not already enabled.
echo "Enabling required APIs..."
gcloud services enable \
    iap.googleapis.com \
    cloudresourcemanager.googleapis.com \
    run.googleapis.com \
    container.googleapis.com \
    iam.googleapis.com \
    pubsub.googleapis.com || true

# Create a Pub/Sub topic
echo "Creating Pub/Sub topic..."
gcloud pubsub topics create messages

# Create a Pub/Sub subscription without a service account (testing to see if this works)
echo "Creating Pub/Sub subscription..."
gcloud pubsub subscriptions create messages-subscription --topic messages \
    --ack-deadline=600 \
    --push-endpoint="https://${SUBSCRIBER_APP_NAME}-${PROJECT_NUMBER}.${REGION}.run.app/pubsub"

# Create a service account for the publisher app
echo "Creating publisher app service account..."
gcloud iam service-accounts create ${PUBLISHER_APP_NAME} \
    --display-name "Publisher App"
sleep 2

# Grant the publisher permission to publish to the topic
echo "Granting publisher app service account permission to publish to the topic..."
for role in roles/pubsub.publisher roles/pubsub.viewer; do
    gcloud pubsub topics add-iam-policy-binding messages \
        --member="serviceAccount:${PUBLISHER_APP_NAME}@${PROJECT_ID}.iam.gserviceaccount.com" \
        --role="$role"
done
