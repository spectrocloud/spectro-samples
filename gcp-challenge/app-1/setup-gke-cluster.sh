#!/bin/bash

# Exit on error
set -e

# Expect this to be set in the environment
: "${PROJECT_ID:?Environment variable PROJECT_ID must be set}"

APP_NAME="publisher-app"
K8S_SERVICE_ACCOUNT="publisher-app"
CLUSTER_NAME="${APP_NAME}-cluster"
REGION="us-central1"
ZONE="${REGION}-a"

# Create the GKE cluster
echo "Creating GKE cluster..."
gcloud container clusters create ${CLUSTER_NAME} \
    --zone=${ZONE} \
    --num-nodes=1 \
    --machine-type=e2-medium \
    --workload-pool=${PROJECT_ID}.svc.id.goog \
    --enable-ip-alias \
    --spot

# Configure kubectl context
echo "Configuring kubectl..."
gcloud container clusters get-credentials ${CLUSTER_NAME} --zone=${ZONE}

# Create the Kubernetes service account if it does not already exist.
echo "Setting up Workload Identity, starting with Kubernetes service account..."
if ! kubectl get serviceaccount ${K8S_SERVICE_ACCOUNT} >/dev/null 2>&1; then
    echo "Creating service account ${K8S_SERVICE_ACCOUNT}..."
    kubectl create serviceaccount ${K8S_SERVICE_ACCOUNT}
fi

# Add IAM policy binding to link the IAM service account to the Kubernetes service account
echo "Setting up IAM policy binding..."
gcloud iam service-accounts add-iam-policy-binding \
    ${APP_NAME}@${PROJECT_ID}.iam.gserviceaccount.com \
    --role roles/iam.workloadIdentityUser \
    --member "serviceAccount:${PROJECT_ID}.svc.id.goog[default/${K8S_SERVICE_ACCOUNT}]"

# Update service account annotation to finish the linking process
echo "Setting service account annotation..."
kubectl annotate serviceaccount ${K8S_SERVICE_ACCOUNT} \
    iam.gke.io/gcp-service-account=${APP_NAME}@${PROJECT_ID}.iam.gserviceaccount.com \
    --overwrite

echo "GKE cluster setup complete!"
echo "Cluster name: ${CLUSTER_NAME}"
echo "Zone: ${ZONE}"
echo "Workload Identity pool: ${PROJECT_ID}.svc.id.goog"

