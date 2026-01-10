# gcp-challenge

Getting a few services deployed for a prospective customer in GCP, connected via Pub/Sub, integrated with Crossplane and other Spectro Cloud software*.

WIP.

*redacted

# GCP project setup (Day 1 operation)

*By "Day 1 operation" we mean this step requires privileged access to GCP and is not something that can be defined 100% in k8s resources, so it cannot be completed by those who only have write access to the GKE cluster, unlike the operations described as "Day 2 operations" below.*

Perform the following steps manually, which aren't yet automated:

- Create a GCP project.
- Enable the IAP API and set up IAP, including filling out the consent screen and taking note of the OAuth client ID and secret.
- Enable the Artifact Registry API and create a repository named "apps" in the us-central-1 region.
- Enable the Cloud DNS API and configure a zone. Take note of the four NS records you must then set in your main DNS registrar,

Then, export the following env vars so that they will be passed into the setup script.

```
export PROJECT_ID="<your GCP project ID>"
export PROJECT_NUMBER="<project number of that project>"
export IAP_CLIENT_ID="<client_id>"
export IAP_CLIENT_SECRET="<client_secret>"
```

Then, run `setup-gcp-project-and-crossplane.sh`. It will:

- Create a GKE cluster
- Create a service account for Crossplane, assign it the Admin role, and create and download a key file for it (to `crossplane-sa-key.json`)
- Install Crossplane into the cluster, with a k8s Secret with the keyfile contents, including the required GCP providers

Now the GCP project is set up and you can peform Day 2 operations.

# Publisher App

This app (in the `app-1` directory) is a web application deployed to GKE that provides a simple UI for publishing messages to a Pub/Sub topic. It consists of:

- A Go web server that handles:
  - GET `/`: Serves an HTML form for composing messages
  - POST `/publish`: AJAX endpoint that publishes messages to the Pub/Sub topic
- Uses Workload Identity to authenticate with GCP services
- Deployed as a GKE service with an Ingress for external access

Run `build-and-push-image.sh` from the `app-1` directory at least once before each deployment.

## Deploy Publisher App and its GCP dependencies (Day 2 operation)

*By "Day 2 operation" we mean that it can be deployed completely using k8s resources (a mix of vanilla k8s resources and Crossplane resources), so it doesn't require special GCP permissions. Anyone with access to create resources in the GKE cluster can do it, including a GitOps setup.*

Run `deploy-app-1.sh` from the root directory to deploy the app.

# Subscriber app

This app (in the `app-2` directory) is a Cloud Run service that:
- Receives Pub/Sub push messages at the `/pubsub` endpoint
- Maintains an in-memory store of the last 5 messages received
- Provides a web UI at `/` to view received messages
- Has a `/clear` endpoint to clear the message history

A push subscription used instead of a pull subscription so that the Cloud Run service can run in scale to zero mode. It is waken up when GCP pushes a message to its `/pubsub` endpoint or when you open its main endpoint in your web browser (to see messages received so far).

## Deploy Subscriber App and its GCP dependencies (Day 2 operation)

TBD
