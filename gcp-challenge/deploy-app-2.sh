#!/bin/bash

set -e

# Add check for required argument
if [ -z "$1" ]; then
    echo "Error: Timestamp argument is required (format: YYYYMMDD-HHMMSS)"
    echo "Example: ./deploy-app-2.sh 20250326-125349"
    exit 1
fi

# Expect this to be set in the environment
: "${PROJECT_NUMBER:?Environment variable PROJECT_NUMBER must be set}"
: "${PROJECT_ID:?Environment variable PROJECT_ID must be set}"
: "${SUBSCRIBER_APP_IAP_CLIENT_ID:?Environment variable SUBSCRIBER_APP_IAP_CLIENT_ID must be set}"
: "${PUBLISHER_APP_IAP_CLIENT_ID:?Environment variable PUBLISHER_APP_IAP_CLIENT_ID must be set}"

IMAGE_TAG_TIMESTAMP="$1"
REGION="us-central1"
ARTIFACT_REPO="apps"
APP_NAME="subscriber-app"
SERVERLESS_NEG_NAME="${APP_NAME}-serverless-neg"
ADDRESS="subscriber-app-address"
MANAGED_ZONE="gcp-challenge"
IAP_SECRET_NAME="subscriber-app-iap-secret"
IAP_CLIENT_ID=${SUBSCRIBER_APP_IAP_CLIENT_ID}
IMAGE="${REGION}-docker.pkg.dev/${PROJECT_ID}/${ARTIFACT_REPO}/subscriber-app:${IMAGE_TAG_TIMESTAMP}"
GCP_SERVICE_ACCOUNT="subscriber-app-sa"
GCP_SERVICE_ACCOUNT_FRIENDLY_NAME="Subscriber App Service Account"
GCP_SERVICE_ACCOUNT_EMAIL="${GCP_SERVICE_ACCOUNT}@${PROJECT_ID}.iam.gserviceaccount.com"
PUBLISHER_APP_NAME="publisher-app"
PUBLISHER_APP_GCP_SERVICE_ACCOUNT="${PUBLISHER_APP_NAME}-sa"
PUBLISHER_APP_GCP_SERVICE_ACCOUNT_EMAIL="${PUBLISHER_APP_GCP_SERVICE_ACCOUNT}@${PROJECT_ID}.iam.gserviceaccount.com"
PROVIDER_CONFIG_REF_NAME="default"

# Create the IAP service account if it doesn't exist
gcloud beta services identity create \
    --service=iap.googleapis.com --project=${PROJECT_ID}

# Pub/Sub subscription
echo "Applying Pub/Sub subscription and Cloud Run service..."
cat <<EOF | kubectl apply -f -
apiVersion: pubsub.gcp.upbound.io/v1beta2
kind: Subscription
metadata:
  name: messages
spec:
  forProvider:
    topic: messages
    ackDeadlineSeconds: 600
    pushConfig:
      pushEndpoint: https://subscriber-app-${PROJECT_NUMBER}.${REGION}.run.app/pubsub
    labels:
      managed-by: crossplane
  providerConfigRef:
    name: ${PROVIDER_CONFIG_REF_NAME}
---
apiVersion: cloudrun.gcp.upbound.io/v1beta2
kind: Service
metadata:
  name: ${APP_NAME}
spec:
  forProvider:
    location: ${REGION}
    template:
      spec:
        serviceAccountName: ${GCP_SERVICE_ACCOUNT_EMAIL}
        containers:
          - image: ${IMAGE}
            resources:
              limits:
                cpu: "1"
                memory: "256Mi"
            env:
              - name: PUBLISHER_APP_URL
                value: "https://${PUBLISHER_APP_NAME}.${MANAGED_ZONE}.palette-adv.spectrocloud.com"
              - name: PUBLISHER_APP_IAP_CLIENT_ID
                value: ${PUBLISHER_APP_IAP_CLIENT_ID}
    traffic:
      - percent: 100
        latestRevision: true
  providerConfigRef:
    name: ${PROVIDER_CONFIG_REF_NAME}
---
apiVersion: cloudrun.gcp.upbound.io/v1beta2
kind: ServiceIAMMember
metadata:
  name: ${APP_NAME}-run-invoker-all-users
spec:
  forProvider:
    location: ${REGION}
    member: allUsers
    role: roles/run.invoker
    service: ${APP_NAME}
  providerConfigRef:
    name: ${PROVIDER_CONFIG_REF_NAME}
---
apiVersion: cloudrun.gcp.upbound.io/v1beta2
kind: ServiceIAMMember
metadata:
  name: allowlist-iap-for-making-requests-to-${APP_NAME}
spec:
  forProvider:
    location: ${REGION}
    member: serviceAccount:service-${PROJECT_NUMBER}@gcp-sa-iap.iam.gserviceaccount.com
    role: roles/run.invoker
    service: ${APP_NAME}
  providerConfigRef:
    name: ${PROVIDER_CONFIG_REF_NAME}
---
apiVersion: cloudplatform.gcp.upbound.io/v1beta1
kind: ServiceAccount
metadata:
  name: ${GCP_SERVICE_ACCOUNT}
spec:
  forProvider:
    displayName: ${GCP_SERVICE_ACCOUNT_FRIENDLY_NAME}
  providerConfigRef:
    name: ${PROVIDER_CONFIG_REF_NAME}
EOF

# This allows the subscriber app to make requests to all other IAP-protected
# web apps. That's not ideal. It only needs to be given access to the publisher
# app, but Crossplane doesn't seem to support this yet. It seems to only
# support the entire project as the resource to create the IAM binding for.
echo "Allowing ${APP_NAME} to make requests to ${PUBLISHER_APP_NAME}..."
cat <<EOF | kubectl apply -f -
apiVersion: iap.gcp.upbound.io/v1beta2
kind: WebIAMMember
metadata:
  name: allow-${APP_NAME}-to-make-requests-to-all-other-apps
spec:
  forProvider:
    member: serviceAccount:${GCP_SERVICE_ACCOUNT_EMAIL}
    role: roles/iap.httpsResourceAccessor
    project: ${PROJECT_ID}
  providerConfigRef:
    name: default
EOF

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
    name: ${PROVIDER_CONFIG_REF_NAME}
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

echo "Applying load balancer..."
cat <<EOF | kubectl apply -f -
apiVersion: compute.gcp.upbound.io/v1beta2
kind: RegionNetworkEndpointGroup
metadata:
  name: ${SERVERLESS_NEG_NAME}
spec:
  forProvider:
    cloudRun:
      service: ${APP_NAME}
    region: ${REGION}
    networkEndpointType: SERVERLESS
---
apiVersion: compute.gcp.upbound.io/v1beta2
kind: BackendService
metadata:
  name: ${APP_NAME}-backend-service
spec:
  forProvider:
    backend:
    - group: https://www.googleapis.com/compute/v1/projects/${PROJECT_ID}/regions/${REGION}/networkEndpointGroups/${SERVERLESS_NEG_NAME}
    iap:
      oauth2ClientId: ${IAP_CLIENT_ID}
      oauth2ClientSecretSecretRef:
        key: client_secret
        name: ${IAP_SECRET_NAME}
        namespace: default
---
apiVersion: compute.gcp.upbound.io/v1beta2
kind: URLMap
metadata:
  name: ${APP_NAME}-url-map
spec:
  forProvider:
    defaultService: ${APP_NAME}-backend-service
---
apiVersion: compute.gcp.upbound.io/v1beta2
kind: ManagedSSLCertificate
metadata:
  name: ${APP_NAME}-cert
spec:
  forProvider:
    managed:
      domains:
        - subscriber-app.gcp-challenge.palette-adv.spectrocloud.com
---
apiVersion: dns.gcp.upbound.io/v1beta2
kind: RecordSet
metadata:
  name: subscriber-app-record-set
spec:
  forProvider:
    managedZone: ${MANAGED_ZONE}
    name: ${APP_NAME}.${MANAGED_ZONE}.palette-adv.spectrocloud.com.
    rrdatas:
      - ${IP_ADDRESS}
    ttl: 300
    type: A
  providerConfigRef:
    name: ${PROVIDER_CONFIG_REF_NAME}
---
apiVersion: compute.gcp.upbound.io/v1beta1
kind: TargetHTTPSProxy
metadata:
  name: ${APP_NAME}-target-https-proxy
spec:
  forProvider:
    urlMap: ${APP_NAME}-url-map
    sslCertificates:
      - ${APP_NAME}-cert
---
apiVersion: compute.gcp.upbound.io/v1beta2
kind: GlobalForwardingRule
metadata:
  name: ${APP_NAME}-forwarding-rule
spec:
  forProvider:
    ipAddressRef:
      name: ${ADDRESS}
    ipProtocol: TCP
    portRange: "443"
    target: https://www.googleapis.com/compute/v1/projects/${PROJECT_ID}/global/targetHttpsProxies/${APP_NAME}-target-https-proxy
EOF
