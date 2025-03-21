#!/bin/bash

# Deploys the app. Assumes the app has already been built and pushed to
# Artifact Registry at least once with the "latest" tag. As many of the GCP
# resources related to the app are deployed via configuration on the app k8s
# YAML (e.g. Service annotations). The rest of the GCP resources are deployed
# using Crossplane.

REGISTRY="us-central1-docker.pkg.dev"
REPO="apps"
APP_NAME="publisher-app"
K8S_SERVICE_ACCOUNT="${APP_NAME}-sa"
GCP_SERVICE_ACCOUNT="${APP_NAME}-sa"
GCP_SERVICE_ACCOUNT_EMAIL="${GCP_SERVICE_ACCOUNT}@${PROJECT_ID}.iam.gserviceaccount.com"
GCP_SERVICE_ACCOUNT_FRIENDLY_NAME="Publisher App Service Account"
PUBSUB_TOPIC="messages"
ADDRESS="gke-app-address"
MANAGED_CERT="managed-cert"
MANAGED_ZONE="gcp-challenge"
IAP_SECRET_NAME="iap-secret"

# Create the static IP to be used with the app's load balancer.
# No forProvider.region because we need a global address, not a regional one.
echo "Creating static IP..."
cat <<EOF | kubectl apply -f -
apiVersion: compute.gcp.upbound.io/v1beta1
kind: GlobalAddress
metadata:
  name: ${ADDRESS}
spec:
  forProvider: {}
  providerConfigRef:
    name: default
EOF

# First wait for the address resource to exist
echo "Waiting for address to be created..."
while ! gcloud compute addresses describe ${ADDRESS} --global &>/dev/null; do
    echo "Waiting..."
    sleep 1
done

# Then wait for it to be fully provisioned
echo "Waiting for static IP to be fully provisioned..."
while [[ $(gcloud compute addresses describe ${ADDRESS} --global --format="value(status)") != "RESERVED" && $(gcloud compute addresses describe ${ADDRESS} --global --format="value(status)") != "IN_USE" ]]; do
    echo "Current status: $(gcloud compute addresses describe ${ADDRESS} --global --format="value(status)")"
    sleep 1
done

IP_ADDRESS=$(gcloud compute addresses describe ${ADDRESS} --global --format="value(address)")

echo "IP address: ${IP_ADDRESS}"

# Create the remaining Kubernetes resources needed to run the app.
echo "Creating remaining Kubernetes resources..."
cat <<EOF | kubectl apply -f -
apiVersion: cloudplatform.gcp.upbound.io/v1beta1
kind: ServiceAccount
metadata:
  name: ${GCP_SERVICE_ACCOUNT}
spec:
  forProvider:
    displayName: ${GCP_SERVICE_ACCOUNT_FRIENDLY_NAME}
  providerConfigRef:
    name: default
---
apiVersion: pubsub.gcp.upbound.io/v1beta1
kind: Topic
metadata:
  name: messages
spec:
  forProvider:
    labels:
      managed-by: crossplane
  providerConfigRef:
    name: default
---
apiVersion: pubsub.gcp.upbound.io/v1beta2
kind: TopicIAMMember
metadata:
  name: topic-iam-member-sa-publisher
spec:
  forProvider:
    member: serviceAccount:${APP_NAME}-sa@${PROJECT_ID}.iam.gserviceaccount.com
    role: roles/pubsub.publisher
    topic: messages
  providerConfigRef:
    name: default
---
apiVersion: pubsub.gcp.upbound.io/v1beta2
kind: TopicIAMMember
metadata:
  name: topic-iam-member-sa-viewer
spec:
  forProvider:
    member: serviceAccount:${APP_NAME}-sa@${PROJECT_ID}.iam.gserviceaccount.com
    role: roles/pubsub.viewer
    topic: messages
  providerConfigRef:
    name: default
---
apiVersion: dns.gcp.upbound.io/v1beta2
kind: RecordSet
metadata:
  name: gke-app-record-set
spec:
  forProvider:
    managedZone: ${MANAGED_ZONE}
    name: ${APP_NAME}.${MANAGED_ZONE}.palette-adv.spectrocloud.com.
    rrdatas:
      - ${IP_ADDRESS}
    ttl: 300
    type: A
  providerConfigRef:
    name: default
---
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
  annotations:
    beta.cloud.google.com/backend-config: '{"default": "config-default"}'
spec:
  type: ClusterIP
  ports:
  - port: 80
    targetPort: 8080
  selector:
    app: ${APP_NAME}
---
apiVersion: networking.gke.io/v1
kind: ManagedCertificate
metadata:
  name: ${MANAGED_CERT}
spec:
  domains:
    - ${APP_NAME}.${MANAGED_ZONE}.palette-adv.spectrocloud.com
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ${APP_NAME}
  annotations:
    kubernetes.io/ingress.global-static-ip-name: ${ADDRESS}
    networking.gke.io/managed-certificates: ${MANAGED_CERT}
    kubernetes.io/ingress.class: "gce"
spec:
  defaultBackend:
    service:
      name: ${APP_NAME}
      port:
        number: 80
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: ${K8S_SERVICE_ACCOUNT}
  annotations:
    iam.gke.io/gcp-service-account: ${GCP_SERVICE_ACCOUNT_EMAIL}
---
apiVersion: cloudplatform.gcp.upbound.io/v1beta2
kind: ServiceAccountIAMMember
metadata:
  name: workload-identity-binding
spec:
  forProvider:
    serviceAccountIdRef:
      name: ${GCP_SERVICE_ACCOUNT}
    role: roles/iam.workloadIdentityUser
    member: serviceAccount:${PROJECT_ID}.svc.id.goog[default/${K8S_SERVICE_ACCOUNT}]
  providerConfigRef:
    name: default
---
apiVersion: cloud.google.com/v1
kind: BackendConfig
metadata:
  name: config-default
spec:
  iap:
    enabled: true
    oauthclientCredentials:
      secretName: ${IAP_SECRET_NAME}
EOF

# Wait for cert to be ready
echo "Waiting for Google to provision the managed certificate (this usually finishes within 20 minutes)..."
kubectl wait --for=jsonpath='{.status.certificateStatus}'=ACTIVE managedcertificate ${MANAGED_CERT} --timeout=3600s

echo "Done! You should be able to reach the app now."
