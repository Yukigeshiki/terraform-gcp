#!/bin/bash

set -e

# --- Sets up the required service accounts and roles to connect a GCP project to Drata --- #

# Log in with `gcloud auth login`
# Create env vars:
# export PROJECT_ID=[project-id]
# export ORG=[org] Bitaccess org: bitaccess.co
# export ADMIN_PROJECT=[admin-project] Bitaccess admin project: tf-admin-343112

DRATA_PROJECT_ROLE="DrataReadOnlyProjectRole"
DRATA_SERVICE_ACCOUNT="drata-service-account"
DRATA_SERVICE_ACCOUNTS_GROUP="drata-service-accounts@${ORG}"

printf "Running for project \"%s\"\n\n" "$PROJECT_ID"

service_account_email="$DRATA_SERVICE_ACCOUNT@$PROJECT_ID.iam.gserviceaccount.com"

# set project and enable required service apis
printf "Setting project \"%s\"...\n\n" "$PROJECT_ID"
gcloud config set project "$PROJECT_ID" --no-user-output-enabled --quiet

printf "Enabling service APIs...\n"
gcloud services enable compute.googleapis.com monitoring.googleapis.com cloudresourcemanager.googleapis.com \
  sqladmin.googleapis.com admin.googleapis.com --no-user-output-enabled --quiet
printf "Service APIs enabled successfully!\n\n"

# create custom role at the project level
printf "Creating custom project role...\n"
gcloud iam roles create "$DRATA_PROJECT_ROLE" --title="Drata Read-Only Project Role" \
  --project="$PROJECT_ID" \
  --description="Service Account for Drata Autopilot to get read access to all project resources" \
  --stage="GA" \
  --permissions=storage.buckets.get,storage.buckets.getIamPolicy \
  --no-user-output-enabled --quiet
printf "Custom project role created successfully!\n\n"

# create service account
printf "Creating service account \"%s\"...\n" "$service_account_email"
gcloud iam service-accounts create "$DRATA_SERVICE_ACCOUNT" --display-name="Drata Service Account" \
  --description="Service Account with read-only access for Drata Autopilot" \
  --no-user-output-enabled --quiet
printf "Service account created successfully!\n\n"

# assign project level roles to service account
printf "Assigning roles to service account \"%s\"...\n" "$service_account_email"
gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member="serviceAccount:$service_account_email" \
  --role="projects/$PROJECT_ID/roles/$DRATA_PROJECT_ROLE" \
  --condition=None \
  --no-user-output-enabled --quiet
gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member="serviceAccount:$service_account_email" \
  --role="roles/viewer" \
  --condition=None \
  --no-user-output-enabled --quiet
printf "Roles assigned successfully!\n\n"

# download key for service account
printf "Creating and downloading key for service account \"%s\"...\n" "$service_account_email"
gcloud iam service-accounts keys create "./$PROJECT_ID-drata-sa-key.json" \
  --iam-account="$service_account_email" \
  --no-user-output-enabled --quiet
printf "Key created and downloaded successfully!\n\n"

# set admin project
printf "Setting admin project...\n\n"
gcloud config set project "$ADMIN_PROJECT" --no-user-output-enabled --quiet

# add service account to service accounts group
printf "Adding service account \"%s\" to service accounts group...\n" "$service_account_email"
gcloud identity groups memberships add --group-email="$DRATA_SERVICE_ACCOUNTS_GROUP" \
  --member-email="$service_account_email" \
  --no-user-output-enabled --quiet
printf "Added to group successfully!\n\n"

printf "Added project to Drata successfully!\nExit with status code 0.\n"
