#!/bin/bash

# Deletes the Pub/Sub and IAM resources created by the setup script.

# Expect this to be set in the environment
: "${PROJECT_ID:?Environment variable PROJECT_ID must be set}"

# Delete the Pub/Sub subscription
gcloud pubsub subscriptions delete messages-subscription --quiet

# Delete the Pub/Sub topic
gcloud pubsub topics delete messages --quiet

# Delete the IAM service accounts
gcloud iam service-accounts delete cloud-run-pubsub-invoker@${PROJECT_ID}.iam.gserviceaccount.com --quiet
gcloud iam service-accounts delete publisher-app@${PROJECT_ID}.iam.gserviceaccount.com --quiet

echo "Teardown complete!"