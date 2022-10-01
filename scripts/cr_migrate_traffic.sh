#!/bin/bash

set -e

# --- Migrates 100% of traffic for a Cloud Run service --- #

## To run this script you must be a Service Owner (be assigned the Cloud Run Service Owner role).

# Create env vars:
# - export PROJECT_ID=[project-id]
# - export SERVICE_NAME=[service-name]
# - export REGION=[region]
# Log in with `gcloud auth login`

gcloud config set project "${PROJECT_ID}" --no-user-output-enabled --quiet

printf "If you would like to migrate to the latest version of \"%s\" please enter the word 'latest', " "${SERVICE_NAME}"
printf "else enter the revision name that you would like to migrate to.\n"
read -r ans

if [ "$ans" == "latest" ]; then
  gcloud run services update-traffic "${SERVICE_NAME}" --to-latest --region "${REGION}"
else
  gcloud run services update-traffic "${SERVICE_NAME}" --to-revisions="$ans"=100 --region "${REGION}"
fi
