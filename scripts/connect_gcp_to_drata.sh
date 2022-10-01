#!/bin/bash

set -e

# --- Sets up the required service accounts and roles to connect GCP to Drata --- #

# Log in with `gcloud auth login`
# install alpha components `gcloud components install alpha`
# Create env vars:
# export ORG=[org] Bitaccess org: bitaccess.co
# export ADMIN_PROJECT=[admin-project] Bitaccess admin project: tf-admin-343112

## The script will execute the following

## org level
# create service accounts group
# create custom role for org level
# grant org level custom role to service accounts group

## project level (per project)
# enable service apis
# create service account
# create custom role for project level
# add custom role for project level to service account
# add service account to service accounts group

IFS='/' && read -ra ORG_VALS <<<"$(gcloud organizations describe "${ORG}" --format="value(name)")"
ORG_ID="${ORG_VALS[1]}"
DRATA_PROJECT_ROLE="DrataReadOnlyProjectRole"
DRATA_ORG_ROLE="DrataReadOnlyOrganizationalRole"
DRATA_SERVICE_ACCOUNT="drata-service-account"
DRATA_SERVICE_ACCOUNTS_GROUP="drata-service-accounts@${ORG}"
COUNTER=0

# set admin project
printf "Setting admin project...\n\n"
gcloud config set project "$ADMIN_PROJECT" --no-user-output-enabled --quiet

# create group for Drata service accounts
printf "Creating group for service accounts...\n"
gcloud identity groups create "$DRATA_SERVICE_ACCOUNTS_GROUP" \
  --organization="bitaccess.co" \
  --display-name="Drata Service Accounts" \
  --description="Group for consolidated permissioning of Drata service accounts" \
  --no-user-output-enabled --quiet
printf "Group created successfully!\n\n"

# create custom role at the org level
printf "Creating custom org role...\n"
gcloud iam roles create "$DRATA_ORG_ROLE" --title="Drata Read-Only Organizational Role" \
  --organization="$ORG_ID" \
  --description="Service Account with read-only access for Drata Autopilot to get organizational IAM data" \
  --stage="GA" \
  --permissions=resourcemanager.organizations.getIamPolicy,storage.buckets.get,storage.buckets.getIamPolicy \
  --no-user-output-enabled --quiet
printf "Custom org role created successfully!\n\n"

# assign the Drata service accounts group the org level roles
printf "Assigning roles to Drata service accounts group...\n"
gcloud alpha organizations get-iam-policy "$ORG_ID" --format json >policy.json
node -p "
  json = require('./policy.json');
  json.bindings.push({ 'members': [ 'group:$DRATA_SERVICE_ACCOUNTS_GROUP' ], 'role': 'organizations/$ORG_ID/roles/$DRATA_ORG_ROLE' });
  json.bindings.push({ 'members': [ 'group:$DRATA_SERVICE_ACCOUNTS_GROUP' ], 'role': 'roles/viewer' });
  JSON.stringify(json);
  " >policy_includes_drata_sa.json
gcloud alpha organizations set-iam-policy "$ORG_ID" policy_includes_drata_sa.json --no-user-output-enabled --quiet
printf "Roles assigned successfully!\n\n"

# cleanup
rm policy.json && rm policy_includes_drata_sa.json

printf "Looping through projects list sorted by project ID...\n\n"
for project_id in $(gcloud projects list --sort-by=projectId --format="value(PROJECT_ID)"); do

  # check whether the project should be connected to Drata
  echo "Would you like to connect project with project ID: \"$project_id\" to Drata? (y/N)"
  read -r ans
  if [ "$ans" != "y" ] && [ "$ans" != "Y" ] && [ "$ans" != "yes" ] && [ "$ans" != "Yes" ]; then
    continue
  fi

  ((COUNTER++))
  printf "Running for project \"%s\" (project no: $COUNTER)\n\n" "$project_id"

  service_account_email="$DRATA_SERVICE_ACCOUNT@$project_id.iam.gserviceaccount.com"

  # set project and enable required service apis
  printf "Setting project \"%s\"...\n\n" "$project_id"
  gcloud config set project "$project_id" --no-user-output-enabled --quiet

  printf "Enabling service APIs...\n"
  gcloud services enable compute.googleapis.com monitoring.googleapis.com cloudresourcemanager.googleapis.com \
    sqladmin.googleapis.com admin.googleapis.com --no-user-output-enabled --quiet
  printf "Service APIs enabled successfully!\n\n"

  # create custom role at the project level
  printf "Creating custom project role...\n"
  gcloud iam roles create "$DRATA_PROJECT_ROLE" --title="Drata Read-Only Project Role" \
    --project="$project_id" \
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
  gcloud projects add-iam-policy-binding "$project_id" \
    --member="serviceAccount:$service_account_email" \
    --role="projects/$project_id/roles/$DRATA_PROJECT_ROLE" \
    --condition=None \
    --no-user-output-enabled --quiet
  gcloud projects add-iam-policy-binding "$project_id" \
    --member="serviceAccount:$service_account_email" \
    --role="roles/viewer" \
    --condition=None \
    --no-user-output-enabled --quiet
  printf "Roles assigned successfully!\n\n"

  # download key for service account
  printf "Creating and downloading key for service account \"%s\"...\n" "$service_account_email"
  gcloud iam service-accounts keys create "./$project_id-drata-sa-key.json" \
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
done

printf "Drata script has run successfully!\nExit with status code 0.\n"
