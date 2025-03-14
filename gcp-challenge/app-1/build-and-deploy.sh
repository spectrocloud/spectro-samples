#!/bin/bash

set -e

# Expect this to be set in the environment
: "${PROJECT_ID:?Environment variable PROJECT_ID must be set}"

export REGISTRY="us-central1-docker.pkg.dev"
export REPO="apps"
export APP_NAME="publisher-app"
export K8S_SERVICE_ACCOUNT="publisher-app"
export PUBSUB_TOPIC="messages"
export CLUSTER_NAME="${APP_NAME}-cluster"
export REGION="us-central1"
export ZONE="${REGION}-a"

# Set up the GKE cluster and kubectl context if the cluster does not already exist.
if ! gcloud container clusters list --region=${ZONE} | grep -q ${CLUSTER_NAME}; then
    echo "Setting up GKE cluster and kubectl context..."
    ./setup-gke-cluster.sh
fi

# Build and push the container image
echo "Building container image..."
docker build -t ${REGISTRY}/${PROJECT_ID}/${REPO}/${APP_NAME} .
docker push ${REGISTRY}/${PROJECT_ID}/${REPO}/${APP_NAME}

# Create the Kubernetes deployment
echo "Creating Kubernetes deployment..."
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ${APP_NAME}
spec:
  replicas: 1
  selector:
    matchLabels:
      app: ${APP_NAME}
  template:
    metadata:
      labels:
        app: ${APP_NAME}
    spec:
      serviceAccountName: ${K8S_SERVICE_ACCOUNT}
      containers:
      - name: ${APP_NAME}
        image: ${REGISTRY}/${PROJECT_ID}/${REPO}/${APP_NAME}
        env:
        - name: PROJECT_ID
          value: "${PROJECT_ID}"
        - name: PUBSUB_TOPIC
          value: "${PUBSUB_TOPIC}"
        ports:
        - containerPort: 8080
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 200m
            memory: 256Mi
---
apiVersion: v1
kind: Service
metadata:
  name: ${APP_NAME}
spec:
  type: ClusterIP
  ports:
  - port: 80
    targetPort: 8080
  selector:
    app: ${APP_NAME}
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ${APP_NAME}
spec:
  defaultBackend:
    service:
      name: ${APP_NAME}
      port:
        number: 80
EOF

echo "Deployment complete! Waiting for ingress external IP... (you can press Ctrl+C to stop this)"
kubectl get ingress ${APP_NAME} --watch
