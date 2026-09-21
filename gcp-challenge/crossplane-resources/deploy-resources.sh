#!/bin/bash

set -e

# Script was used before to get the app deployed with Crossplane except for
# other GCP resources like Pub/Sub subscription, IAM service accounts,
# IAM bindings, and IAP config. That needs to be converted to Crossplane next
# (including load balancer Crossplane resources since the manually-configured
# load balancer is a prerequisite for IAP). The below can be referenced.

# # Expect this to be set in the environment
# : "${PROJECT_ID:?Environment variable PROJECT_ID must be set}"
# : "${PROJECT_NUMBER:?Environment variable PROJECT_NUMBER must be set}"

# REGION="us-central1"
# PUBLISHER_APP_NAME="publisher-app"

# # If deleting the Pub/Sub topic, we also need to delete the subscription or else the old
# # subscription will be orphaned (see next step).
# gcloud pubsub subscriptions delete messages-subscription || true

# # Delete the Pub/Sub topic if it exists. This is needed because of the workflow where sometimes
# # we need to recreate the topic and re-apply an IAM policy binding between it and the publisher app.
# # TODO: Clean up demo so this is not needed.
# gcloud pubsub topics delete messages || true

# # Pub/Sub topic
# cat <<EOF | kubectl apply -f -
# apiVersion: pubsub.gcp.upbound.io/v1beta1
# kind: Topic
# metadata:
#   name: messages
# spec:
#   forProvider:
#     labels:
#       managed-by: crossplane
#   providerConfigRef:
#     name: default
# ---
# apiVersion: pubsub.gcp.upbound.io/v1beta2
# kind: TopicIAMMember
# metadata:
#   name: topic-iam-member-sa-publisher
# spec:
#   forProvider:
#     member: serviceAccount:${PUBLISHER_APP_NAME}@${PROJECT_ID}.iam.gserviceaccount.com
#     role: roles/pubsub.publisher
#     topic: messages
# ---
# apiVersion: pubsub.gcp.upbound.io/v1beta2
# kind: TopicIAMMember
# metadata:
#   name: topic-iam-member-sa-viewer
# spec:
#   forProvider:
#     member: serviceAccount:${PUBLISHER_APP_NAME}@${PROJECT_ID}.iam.gserviceaccount.com
#     role: roles/pubsub.viewer
#     topic: messages
# EOF

# # Below is in progress, this needs to be tested

# # Pub/Sub subscription
# cat <<EOF | kubectl apply -f -
# apiVersion: pubsub.gcp.upbound.io/v1beta2
# kind: Subscription
# metadata:
#   name: messages-subscription
# spec:
#   forProvider:
#     topic: messages
#     ackDeadlineSeconds: 600
#     pushConfig:
#       pushEndpoint: https://subscriber-app-${PROJECT_NUMBER}.${REGION}.run.app/pubsub
#     labels:
#       managed-by: crossplane
#   providerConfigRef:
#     name: default
# EOF

# # Cloud Run service
# cat <<EOF | kubectl apply -f -
# apiVersion: cloudrun.gcp.upbound.io/v1beta2
# kind: Service
# metadata:
#   name: subscriber-app
# spec:
#   forProvider:
#     location: us-central1
#     template:
#       spec:
#         containers:
#           - image: us-central1-docker.pkg.dev/${PROJECT_ID}/apps/subscriber-app:latest
#             resources:
#               limits:
#                 cpu: "1"
#                 memory: "256Mi"
#     traffic:
#       - percent: 100
#         latestRevision: true
#   providerConfigRef:
#     name: default
# ---
# apiVersion: cloudrun.gcp.upbound.io/v1beta2
# kind: ServiceIAMMember
# metadata:
#   name: subscriber-app-public
# spec:
#   forProvider:
#     location: us-central1
#     member: allUsers
#     role: roles/run.invoker
#     service: subscriber-app
# EOF

# echo "Waiting 10 seconds for k8s to reconcile GCP resources..."
# sleep 10

# # Bounce the publisher app pod. This is needed in case the topic was deleted and recreated in the
# # step above.
# echo "Bouncing publisher pod to get it to reconnect to Pub/Sub..."
# kubectl config use-context $(kubectl config get-contexts | grep gke | tr -s " " | cut -d" " -f2)
# kubectl delete pod -l app=publisher-app || true
