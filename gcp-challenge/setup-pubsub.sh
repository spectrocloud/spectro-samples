#!/bin/bash
# Expect these to be set in the environment
: "${PROJECT_ID:?Environment variable PROJECT_ID must be set}"
: "${PROJECT_NUMBER:?Environment variable PROJECT_NUMBER must be set}"

export REGION="us-central1"
export APP_NAME="subscriber-app"

set -e

# Create a Pub/Sub topic
gcloud pubsub topics create messages

# Create a service account to represent the Pub/Sub subscription identity
gcloud iam service-accounts create cloud-run-pubsub-invoker \
    --display-name "Cloud Run Pub/Sub Invoker"

# Give the invoker service account permission to invoke the Cloud Runservice
gcloud run services add-iam-policy-binding ${APP_NAME} \
    --member="serviceAccount:cloud-run-pubsub-invoker@${PROJECT_ID}.iam.gserviceaccount.com" \
    --role=roles/run.invoker \
    --region=${REGION}

# Allow Pub/Sub to create authentication tokens in your project
gcloud projects add-iam-policy-binding ${PROJECT_ID} \
   --member=serviceAccount:service-${PROJECT_NUMBER}@gcp-sa-pubsub.iam.gserviceaccount.com \
   --role=roles/iam.serviceAccountTokenCreator

# Create a Pub/Sub subscription with the service account
gcloud pubsub subscriptions create messages-subscription --topic messages \
--ack-deadline=600 \
--push-endpoint="https://${APP_NAME}-${PROJECT_NUMBER}.${REGION}.run.app/pubsub" \
--push-auth-service-account="cloud-run-pubsub-invoker@${PROJECT_ID}.iam.gserviceaccount.com"
