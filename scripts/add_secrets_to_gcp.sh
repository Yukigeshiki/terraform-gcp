#!/bin/bash

#set -e

# --- Uses a .env file to add secrets/config to GCP Secret Manager --- #

# Log in with `gcloud auth login` - user must have "Secret Manager Admin" role for the project where the secrets
# are to be added.
# Create env vars:
# - export PROJECT_ID=[project-id]

# Copy a .env file into the scripts folder - it will be read in line by line and each env var added to GCP
# Secret Manager.

# NB1: The .env file WILL BE REMOVED by the script once the job has completed. If you don't want this functionality
# comment out the rm line below.
# NB2: If a secret already exists it's version will be updated; otherwise it will show a "NOT_FOUND" error and create
# the secret before creating a version. If you don't want a secret version updated, don't include it in the .env file.

gcloud config set project "${PROJECT_ID}"

input="./.env"

while read -r line || [ -n "$line" ]; do

  # skip empty lines and comments
  if [ -z "$line" ] || [[ "$line" =~ ^[[:space:]]*# ]]; then
    continue
  fi

  key=$(echo "$line" | cut -d'=' -f1 | tr "[:upper:]" "[:lower:]")
  value=$(echo "$line" | cut -d'=' -f2)

  # check if secret exists and add if not
  if ! gcloud secrets versions access latest --secret="$key" --no-user-output-enabled --quiet; then
    gcloud secrets create "$key" --replication-policy="automatic"
  fi

  echo -n "$value" | gcloud secrets versions add "$key" --data-file=-

done <"$input"

rm .env # comment out this line if you don't want the .env file removed once the script completes

printf "\nSecrets or config added or updated successfully! \n\n"
