# gcp-challenge

Getting a few services deployed for a prospective customer in GCP, connected via Pub/Sub, integrated with Crossplane and other Spectro Cloud software*.

WIP.

*redacted

# GCP project setup

Ensure you have a GCP user account with Owner privileges on a project.

Export env vars for your project ID and project number (get the project number from the GCP console welcome page after selecting your project). This passes them to each deploy/teardown script you run.

```
export PROJECT_ID="<your GCP project ID>"
export PROJECT_NUMBER="<project number of that project>"
```

## Pub/Sub topic and subscription

Run `setup-pubsub.sh` to create the topic and subscription.

## Publisher app

This app (in the `app-1` directory) is a web application deployed to GKE that provides a simple UI for publishing messages to a Pub/Sub topic. It consists of:

- A Go web server that handles:
  - GET `/`: Serves an HTML form for composing messages
  - POST `/publish`: AJAX endpoint that publishes messages to the Pub/Sub topic
- Uses Workload Identity to authenticate with GCP services
- Deployed as a GKE service with an Ingress for external access

Deploy it by:

1. Create the GKE cluster and set up IAM:
   ```bash
   ./create-gke-cluster.sh
   ```

2. Build and deploy the application:
   ```bash
   ./build-and-deploy.sh
   ```

The app will be accessible via the Ingress IP address once deployment is complete.

To tear down the infrastructure:
```bash
./teardown.sh
```

You can test the app locally with:
```bash
./start-app-local.sh
```

Note that because this app uses the GCP Pub/Sub SDK, you must have a key file named `publisher-app.json` in the app's directory for the app to come up locally. Otherwise, it will show an error from the SDK in its logs.

## Subscriber app

This app (in the `app-2` directory) is a Cloud Run service that:
- Receives Pub/Sub push messages at the `/pubsub` endpoint
- Maintains an in-memory store of the last 5 messages received
- Provides a web UI at `/` to view received messages
- Has a `/clear` endpoint to clear the message history

A push subscription used instead of a pull subscription so that the Cloud Run service can run in scale to zero mode. It is waken up when GCP pushes a message to its `/pubsub` endpoint or when you open its main endpoint in your web browser (to see messages received so far).

Deploy it by:

1. Build and deploy to Cloud Run:
   ```bash
   ./build-and-deploy.sh
   ```

The app is configured to:
- Accept unauthenticated requests (for the web UI)
- Receive messages from the Pub/Sub subscription created in `setup-pubsub.sh`
- Run as a managed Cloud Run service in us-central1

You can test the app locally with:
```bash
./start-app-local.sh
```

And test message reception with:
```bash
./test-request.sh  # For local testing
./test-request-prod.sh  # For testing the deployed service
```

These scripts simulate the kind of HTTP requests the push subscription makes to the service.

## To do

- IAP for authenticating users to the web pages and other endpoints of each app
- Adding Crossplane versions of each GCP resource currently being brought up via the Bash scripts
- Integrating the Crossplane version of each resource with other Spectro Cloud software
