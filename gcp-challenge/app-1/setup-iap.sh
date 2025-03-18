#!/bin/bash

# Requires the GKE application to have been deployed at least one.

NAMESPACE=default
IAP_SECRET_NAME=iap-client-secret

# Create k8s secret for the IAP client ID and secret if one doesn't exist.
if ! kubectl get secret ${IAP_SECRET_NAME} &>/dev/null; then
    echo "creating IAP client secret"

    # Error if env variables are not set.
    if [ -z "$IAP_CLIENT_ID" ] || [ -z "$IAP_CLIENT_SECRET" ]; then
        echo "IAP_CLIENT_ID and IAP_CLIENT_SECRET must be set"
        exit 1
    fi

    kubectl create secret generic ${IAP_SECRET_NAME} \
        --from-literal=client_id=$IAP_CLIENT_ID \
        --from-literal=client_secret=$IAP_CLIENT_SECRET
else
    echo "IAP client secret already exists, skipping creating it"
fi

cat <<EOF | kubectl apply -f -
apiVersion: cloud.google.com/v1
kind: BackendConfig
metadata:
  name: config-default
  namespace: ${NAMESPACE}
spec:
  iap:
    enabled: true
    oauthclientCredentials:
      secretName: ${IAP_SECRET_NAME}
EOF
