#!/bin/bash

set -e

# --- Creates a global external HTTPS load balancer for Cloud Run --- #

# Log in with `gcloud auth login` - user must have "Owner" role on project containing service
# Create env vars:
# - export PROJECT_ID=[project-id]
# - export SERVICE_NAME=[service-name]
# - export REGION=[region]
# - export DOMAIN_NAME=[domain-name] ## this includes subdomain(s) eg. dev.example.com or *.example.com

gcloud config set project "${PROJECT_ID}"

# make sure the Cloud Run service exists
printf "Checking %s service exists...\n" "${SERVICE_NAME}"
if ! gcloud beta run services list | grep -q "$SERVICE_NAME"; then
  printf "Service \"%s\" does not exist!\nExited with status code 1.\n" "$SERVICE_NAME"
  exit 1
fi
printf "Check successful!\n\n"

# make sure the Cloud Run backend security policy has been created
printf "Checking cr-backend-security-policy exists...\n"
if ! gcloud beta compute security-policies list | grep -q cr-backend-security-policy; then
  printf "Security Policy \"cr-backend-security-policy\" does not exist!\nExited with status code 1.\n"
  exit 1
fi
printf "Check successful!\n\n"

# resource names
STATIC_IP_NAME="$SERVICE_NAME-static-ip"
SERVERLESS_NEG_NAME="$SERVICE_NAME-serverless-neg"
BACKEND_SERVICE_NAME="$SERVICE_NAME-backend-service"
SSL_CERTIFICATE_NAME="$SERVICE_NAME-ssl-certificate"
URL_MAP_NAME="$SERVICE_NAME-url-map"
TARGET_HTTPS_PROXY_NAME="$SERVICE_NAME-target-https-proxy"
HTTPS_FORWARDING_RULE_NAME="$SERVICE_NAME-https-forwarding-rule"

# create static IP for load balancer
printf "Creating static IP address for load balancer...\n"
gcloud compute addresses create "$STATIC_IP_NAME" --network-tier=PREMIUM --ip-version=IPV4 --global &&
  STATIC_IP=$(gcloud compute addresses describe "$STATIC_IP_NAME" --format="get(address)" --global)
printf "Creating static IP address for load balancer completed!\n\n"

# create Google-managed SSL certificate
printf "Creating Google-managed SSL certificate...\n"
gcloud beta compute ssl-certificates create "$SSL_CERTIFICATE_NAME" --domains "$DOMAIN_NAME" --global
printf "Creating Google-managed SSL certificate completed!\n\n"

# create a serverless NEG for your serverless app
printf "Creating a serverless NEG for your serverless app...\n"
gcloud beta compute network-endpoint-groups create "$SERVERLESS_NEG_NAME" \
  --region="$REGION" \
  --network-endpoint-type=serverless \
  --cloud-run-service="$SERVICE_NAME"
printf "Creating a serverless NEG for your serverless app completed!\n\n"

# create a backend service
printf "Creating a backend service...\n"
gcloud beta compute backend-services create "$BACKEND_SERVICE_NAME" \
  --load-balancing-scheme=EXTERNAL_MANAGED \
  --global
printf "Creating a backend service completed!\n\n"

# add the Cloud Run backend security policy (created by Terraform in all CR projects)
printf "Adding Cloud Run load balancer security policy...\n"
gcloud beta compute backend-services update "$BACKEND_SERVICE_NAME" \
  --security-policy=cr-backend-security-policy \
  --global
printf "Cloud Run load balancer security policy added successfully!\n\n"

# add the serverless NEG as a backend to the backend service
printf "Adding the serverless NEG as a backend to the backend service...\n"
gcloud beta compute backend-services add-backend "$BACKEND_SERVICE_NAME" \
  --global \
  --network-endpoint-group="$SERVERLESS_NEG_NAME" \
  --network-endpoint-group-region="$REGION"
printf "Adding the serverless NEG as a backend to the backend service completed!\n\n"

# create a URL map to route incoming requests to the backend service
printf "Creating a URL map to route incoming requests to the backend service...\n"
gcloud beta compute url-maps create "$URL_MAP_NAME" --default-service "$BACKEND_SERVICE_NAME"
printf "Creating a URL map to route incoming requests to the backend service completed!\n\n"

# create an HTTPS target proxy
printf "Creating an HTTPS target proxy...\n"
gcloud beta compute target-https-proxies create "$TARGET_HTTPS_PROXY_NAME" \
  --ssl-certificates="$SSL_CERTIFICATE_NAME" \
  --url-map="$URL_MAP_NAME"
printf "Creating an HTTPS target proxy completed!\n\n"

# create a forwarding rule to route incoming requests to the proxy
printf "Creating a forwarding rule to route incoming requests to the proxy...\n"
gcloud beta compute forwarding-rules create "$HTTPS_FORWARDING_RULE_NAME" \
  --load-balancing-scheme=EXTERNAL_MANAGED \
  --network-tier=PREMIUM \
  --address="$STATIC_IP" \
  --target-https-proxy="$TARGET_HTTPS_PROXY_NAME" \
  --global \
  --ports=443
printf "Creating a forwarding rule to route incoming requests to the proxy completed!\n\n"

printf "Global external HTTPS load balancer for Cloud Run service \"%s\", created! " "$SERVICE_NAME"
printf "Your IP address is: %s\nExit with status code 0.\n" "$STATIC_IP"
