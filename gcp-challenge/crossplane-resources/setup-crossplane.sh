#!/bin/bash

set -e

# Expect this to be set in the environment
: "${PROJECT_ID:?Environment variable PROJECT_ID must be set}"
: "${PROJECT_NUMBER:?Environment variable PROJECT_NUMBER must be set}"

REGION="us-central1"
CROSSPLANE_NAMESPACE="crossplane-system"

# Install Crossplane into a kind cluster
kind create cluster --name crossplane-cluster

helm repo add crossplane-stable https://charts.crossplane.io/stable
helm repo update

helm install crossplane \
    crossplane-stable/crossplane \
    --namespace ${CROSSPLANE_NAMESPACE} \
    --create-namespace

# Wait for Crossplane pods to exist and then be ready
echo "Waiting for Crossplane pods to be created..."
while [[ $(kubectl get pods -n ${CROSSPLANE_NAMESPACE} 2>/dev/null | wc -l) -le 1 ]]; do
    echo "Waiting..."
    sleep 1
done
echo "Waiting for Crossplane pods to be ready..."
kubectl wait --for=condition=Ready pods --all -n ${CROSSPLANE_NAMESPACE} --timeout=300s

# Install each required GCP Crossplane provider
for provider in pubsub cloudrun; do
    cat <<EOF | kubectl apply -f -
apiVersion: pkg.crossplane.io/v1
kind: Provider
metadata:
  name: provider-gcp-${provider}
spec:
  package: xpkg.crossplane.io/crossplane-contrib/provider-gcp-${provider}:v1.12.0
EOF
done

CROSSPLANE_SA="crossplane-sa"
K8S_SECRET_KEY="creds"

# Create a service account for Crossplane if one doesn't exist
if ! gcloud iam service-accounts list --filter="email:${CROSSPLANE_SA}@${PROJECT_ID}.iam.gserviceaccount.com" --format="get(email)" | grep -q "${CROSSPLANE_SA}"; then
    echo "Creating service account ${CROSSPLANE_SA}..."
    gcloud iam service-accounts create ${CROSSPLANE_SA} \
        --display-name="Crossplane Service Account"
else
    echo "Service account ${CROSSPLANE_SA} already exists"
fi

# Assign roles/admin to the service account
echo "Assigning admin role to ${CROSSPLANE_SA}..."
gcloud projects add-iam-policy-binding ${PROJECT_ID} \
    --member="serviceAccount:${CROSSPLANE_SA}@${PROJECT_ID}.iam.gserviceaccount.com" \
    --role="roles/admin"

# Create a key for the service account and save it locally
gcloud iam service-accounts keys create ${CROSSPLANE_SA}-key.json \
    --iam-account=${CROSSPLANE_SA}@${PROJECT_ID}.iam.gserviceaccount.com

# Create Secret with GCP credentials for Crossplane from the key file 
kubectl create secret generic gcp-secret \
    --from-file=${K8S_SECRET_KEY}=${CROSSPLANE_SA}-key.json \
    --namespace ${CROSSPLANE_NAMESPACE}

# Wait for ProviderConfig CRD to be ready
echo "Waiting for ProviderConfig CRD to be created..."
while ! kubectl get crd providerconfigs.gcp.upbound.io 2>/dev/null; do
    echo "Waiting..."
    sleep 1
done

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

# Add "cluster-admin" role to the provider pods' service accounts and bounce the pods. This is a
# workaround for https://github.com/crossplane/docs/issues/888. Without it, resources won't sync.
for provider in pubsub cloudrun; do
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

echo "Crossplane setup complete."
