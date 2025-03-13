#!/bin/bash

# Exit on error
set -e

# Expect this to be set in the environment
: "${PROJECT_ID:?Environment variable PROJECT_ID must be set}"

# Default values
APP_NAME="publisher-app"
K8S_SERVICE_ACCOUNT="publisher-app"
CLUSTER_NAME="${APP_NAME}-cluster"
REGION="us-central1"
ZONE="${REGION}-a"
SKIP_ENABLE_APIS=false
SKIP_SETUP_CLUSTER=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --skip-enable-apis)
            SKIP_ENABLE_APIS=true
            shift
            ;;
        --skip-setup-cluster)
            SKIP_SETUP_CLUSTER=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Enable required APIs if not skipped
if [ "$SKIP_ENABLE_APIS" = false ]; then
    echo "Enabling required APIs..."
    gcloud services enable \
        container.googleapis.com \
        iap.googleapis.com \
        cloudresourcemanager.googleapis.com || true
else
    echo "Skipping API enablement..."
fi

if [ "$SKIP_SETUP_CLUSTER" = false ]; then
    # Check if cluster exists
    if gcloud container clusters describe ${CLUSTER_NAME} --zone=${ZONE} >/dev/null 2>&1; then
        echo "Cluster ${CLUSTER_NAME} already exists"
    else
        # Create the GKE cluster
        echo "Creating GKE cluster..."
        gcloud container clusters create ${CLUSTER_NAME} \
            --zone=${ZONE} \
            --num-nodes=1 \
            --machine-type=e2-medium \
            --workload-pool=${PROJECT_ID}.svc.id.goog \
            --enable-ip-alias \
            --spot
    fi

    # Configure kubectl context
    echo "Configuring kubectl..."
    gcloud container clusters get-credentials ${CLUSTER_NAME} --zone=${ZONE}

    # Create the Kubernetes service account
    echo "Setting up Workload Identity..."
    if ! kubectl get serviceaccount ${K8S_SERVICE_ACCOUNT} >/dev/null 2>&1; then
        echo "Creating service account ${K8S_SERVICE_ACCOUNT}..."
        kubectl create serviceaccount ${K8S_SERVICE_ACCOUNT}
    fi
fi

# Delete the old IAM service account if it exists
if gcloud iam service-accounts describe ${APP_NAME}@${PROJECT_ID}.iam.gserviceaccount.com >/dev/null 2>&1; then
    echo "Deleting old IAM service account..."
    gcloud iam service-accounts delete ${APP_NAME}@${PROJECT_ID}.iam.gserviceaccount.com --quiet
fi

# Create the IAM service account
echo "Creating IAM service account..."
gcloud iam service-accounts create ${APP_NAME} \
    --display-name="Publisher App"

sleep 1

# Add Pub/Sub roles to the IAM service account
echo "Adding Pub/Sub Publisher and Viewer roles to the IAM service account..."
for role in "roles/pubsub.publisher" "roles/pubsub.viewer"; do
    gcloud projects add-iam-policy-binding ${PROJECT_ID} \
        --role ${role} \
        --member "serviceAccount:${APP_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"
done

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

