#!/bin/bash

# Performs GCP project setup including GKE cluster creation and Crossplane installation.
# Assumes the project is already created, has billing enabled,
# and that gcloud is already authenticated.

set -e

# Expect this to be set in the environment
: "${PROJECT_ID:?Environment variable PROJECT_ID must be set}"
: "${PROJECT_NUMBER:?Environment variable PROJECT_NUMBER must be set}"
: "${PUBLISHER_APP_IAP_CLIENT_ID:?Environment variable PUBLISHER_APP_IAP_CLIENT_ID must be set}"
: "${PUBLISHER_APP_IAP_CLIENT_SECRET:?Environment variable PUBLISHER_APP_IAP_CLIENT_SECRET must be set}"
: "${SUBSCRIBER_APP_IAP_CLIENT_ID:?Environment variable SUBSCRIBER_APP_IAP_CLIENT_ID must be set}"
: "${SUBSCRIBER_APP_IAP_CLIENT_SECRET:?Environment variable SUBSCRIBER_APP_IAP_CLIENT_SECRET must be set}"

REGION="us-central1"
ZONE="${REGION}-a"
CLUSTER_NAME="gke-cluster"
CROSSPLANE_NAMESPACE="crossplane-system"
CROSSPLANE_SA="crossplane-sa"
CROSSPLANE_PROVIDERS="cloudplatform cloudrun compute dns pubsub iap"
CROSSPLANE_PROVIDER_VERSION="v1.12.1"
PUBLISHER_APP_IAP_SECRET_NAME="publisher-app-iap-secret"
SUBSCRIBER_APP_IAP_SECRET_NAME="subscriber-app-iap-secret"

# Ensure gcloud is set to the correct project.
echo "Setting gcloud project to ${PROJECT_ID}..."
gcloud config set project ${PROJECT_ID}

# Enable required APIs if they aren't already enabled.
echo "Enabling required APIs..."
gcloud services enable \
    artifactregistry.googleapis.com \
    certificatemanager.googleapis.com \
    cloudbuild.googleapis.com \
    cloudresourcemanager.googleapis.com \
    container.googleapis.com \
    dns.googleapis.com \
    iam.googleapis.com \
    iap.googleapis.com \
    pubsub.googleapis.com \
    run.googleapis.com || true

# Create Artifact Registry repository if it doesn't exist
echo "Creating Artifact Registry repository..."
if ! gcloud artifacts repositories list --location=${REGION} | grep -q "apps"; then
    gcloud artifacts repositories create apps \
        --repository-format=docker \
        --location=${REGION} \
        --description="Docker repository for application images"
    echo "Artifact Registry repository 'apps' created."
else
    echo "Artifact Registry repository 'apps' already exists."
fi

# Create Cloud DNS zone if it doesn't exist
echo "Creating Cloud DNS zone..."
if ! gcloud dns managed-zones list | grep -q "gcp-challenge"; then
    gcloud dns managed-zones create "gcp-challenge" \
        --dns-name="gcp-challenge.palette-adv.spectrocloud.com" \
        --description="DNS zone for GCP challenge"
    echo "Cloud DNS zone 'gcp-challenge' created."
else
    echo "Cloud DNS zone 'gcp-challenge' already exists."
fi

# Display nameservers
echo "Nameservers for DNS zone:"
gcloud dns managed-zones describe "gcp-challenge" \
    --format="get(nameServers)" | tr ';' '\n'

# Create the GKE cluster if it doesn't exist.
if ! gcloud container clusters list --region=${ZONE} | grep -q ${CLUSTER_NAME}; then
    echo "Creating GKE cluster..."
    gcloud container clusters create ${CLUSTER_NAME} \
        --zone=${ZONE} \
        --num-nodes=1 \
        --machine-type=e2-standard-2 \
        --workload-pool=${PROJECT_ID}.svc.id.goog \
        --enable-ip-alias

    echo "GKE cluster created."
fi

echo "Waiting two minutes..."
sleep 120

# Get credentials and set context to GKE cluster
gcloud container clusters get-credentials ${CLUSTER_NAME} --zone=${ZONE}

# Install Crossplane into the GKE cluster
echo "Installing Crossplane..."
helm repo add crossplane-stable https://charts.crossplane.io/stable
helm repo update

echo "Installing Crossplane Helm chart..."
helm install crossplane \
    crossplane-stable/crossplane \
    --namespace ${CROSSPLANE_NAMESPACE} \
    --create-namespace

# Wait for Crossplane pods to exist and then be ready.
echo "Waiting for Crossplane pods to be created..."
while [[ $(kubectl get pods -n ${CROSSPLANE_NAMESPACE} 2>/dev/null | wc -l) -le 1 ]]; do
    echo "Waiting..."
    sleep 1
done
echo "Waiting for Crossplane pods to be ready..."
kubectl wait --for=condition=Ready pods --all -n ${CROSSPLANE_NAMESPACE} --timeout=300s

echo "Waiting for 10 seconds..."
sleep 10

# Install each required GCP Crossplane provider
for provider in ${CROSSPLANE_PROVIDERS}; do
    cat <<EOF | kubectl apply -f -
apiVersion: pkg.crossplane.io/v1
kind: Provider
metadata:
    name: provider-gcp-${provider}
spec:
    package: xpkg.crossplane.io/crossplane-contrib/provider-gcp-${provider}:${CROSSPLANE_PROVIDER_VERSION}
EOF
done

echo "Waiting for 10 seconds..."
sleep 10

# Create a GCP service account for Crossplane if one doesn't exist.
if ! gcloud iam service-accounts list --filter="email:${CROSSPLANE_SA}@${PROJECT_ID}.iam.gserviceaccount.com" --format="get(email)" | grep -q "${CROSSPLANE_SA}"; then
    echo "Creating GCP service account ${CROSSPLANE_SA}..."
    gcloud iam service-accounts create ${CROSSPLANE_SA} \
        --display-name="Crossplane Service Account"
    
    # Add a delay and retry mechanism for the IAM binding
    echo "Waiting for service account to be fully propagated..."
    for i in {1..10}; do
        if gcloud projects add-iam-policy-binding ${PROJECT_ID} \
            --member="serviceAccount:${CROSSPLANE_SA}@${PROJECT_ID}.iam.gserviceaccount.com" \
            --role="roles/admin"; then
            echo "Successfully assigned admin role to ${CROSSPLANE_SA}"
            break
        else
            echo "Attempt $i: Service account not ready yet, waiting 5 seconds..."
            sleep 1
        fi
        
        if [ $i -eq 5 ]; then
            echo "Failed to assign role after 5 attempts"
            exit 1
        fi
    done
else
    # If the service account already exists, just try to add the binding once
    echo "Assigning admin role to ${CROSSPLANE_SA} GCP service account..."
    gcloud projects add-iam-policy-binding ${PROJECT_ID} \
        --member="serviceAccount:${CROSSPLANE_SA}@${PROJECT_ID}.iam.gserviceaccount.com" \
        --role="roles/admin"
fi

echo "Sleeping for 10 seconds..."
sleep 10

# Create a key for the service account and save it locally.
echo "Creating key for ${CROSSPLANE_SA}, saving it to disk at ${CROSSPLANE_SA}-key.json..."
gcloud iam service-accounts keys create ${CROSSPLANE_SA}-key.json \
    --iam-account=${CROSSPLANE_SA}@${PROJECT_ID}.iam.gserviceaccount.com

# Create a k8s Secret with GCP credentials for Crossplane from the key file.
echo "Creating k8s Secret with GCP credentials for Crossplane..."
kubectl create secret generic gcp-secret \
    --from-file=creds=${CROSSPLANE_SA}-key.json \
    --namespace ${CROSSPLANE_NAMESPACE}

# Wait for ProviderConfig CRD to be ready.
echo "Waiting for ProviderConfig CRD to be created..."
while ! kubectl get crd providerconfigs.gcp.upbound.io 2>/dev/null; do
    echo "Waiting..."
    sleep 1
done

echo "Waiting for 10 seconds..."
sleep 10

# Create a ProviderConfig for the Crossplane GCP provider
cat <<EOF | kubectl apply -f -
apiVersion: gcp.upbound.io/v1beta1
kind: ProviderConfig
metadata:
  name: default
spec:
  projectID: ${PROJECT_ID}
  credentials:
    source: Secret
    secretRef:
      namespace: crossplane-system
      name: gcp-secret
      key: creds
EOF

echo "Waiting for 10 seconds..."

# Add "cluster-admin" role to the provider pods' service accounts and bounce the pods
for provider in ${CROSSPLANE_PROVIDERS}; do
    echo "Waiting for ${provider} provider pod to be created..."
    while [[ $(kubectl get pods -l pkg.crossplane.io/provider=provider-gcp-${provider} -n ${CROSSPLANE_NAMESPACE} 2>/dev/null | wc -l) -le 1 ]]; do
        echo "Waiting..."
        sleep 1
    done
    
    SA_NAME=$(kubectl get pods -l pkg.crossplane.io/provider=provider-gcp-${provider} -n ${CROSSPLANE_NAMESPACE} -o jsonpath="{.items[0].spec.serviceAccountName}")
    echo "Granting cluster-admin to provider service account ${SA_NAME}..."
    kubectl create clusterrolebinding provider-gcp-${provider}-admin \
        --clusterrole cluster-admin \
        --serviceaccount=${CROSSPLANE_NAMESPACE}:${SA_NAME}
    
    kubectl delete pod -l pkg.crossplane.io/provider=provider-gcp-${provider} -n ${CROSSPLANE_NAMESPACE}
done

# Create k8s Secrets with IAP credentials.
echo "Creating Publisher App IAP credentials k8s Secret..."
kubectl create secret generic ${PUBLISHER_APP_IAP_SECRET_NAME} \
    --from-literal=client_id=${PUBLISHER_APP_IAP_CLIENT_ID} \
    --from-literal=client_secret=${PUBLISHER_APP_IAP_CLIENT_SECRET}

echo "Creating Subscriber App IAP credentials k8s Secret..."
kubectl create secret generic ${SUBSCRIBER_APP_IAP_SECRET_NAME} \
    --from-literal=client_id=${SUBSCRIBER_APP_IAP_CLIENT_ID} \
    --from-literal=client_secret=${SUBSCRIBER_APP_IAP_CLIENT_SECRET}

echo "Done."