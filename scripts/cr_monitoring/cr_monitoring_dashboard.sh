#!/bin/bash

set -e

# --- Adds a project to a Monitoring Scope, and creates a Cloud Run monitoring dashboard for that project --- #

# Log in with `gcloud auth login` - user must have "Owner" role on both monitored and scoping projects
# Create env vars:
# - export SERVICE_NAME=[cloud-run-service]
# - export REGION=[cloud-run-service-region]
# - export SCOPING_PROJECT_ID=[scoping-project-id]
# - export MONITORED_PROJECT_ID=[monitored-project-id]
# - export TOKEN=$(gcloud auth print-access-token)

# set monitored project and check service exists
printf "Checking %s service exists in project %s...\n" "${SERVICE_NAME}" "${MONITORED_PROJECT_ID}"
gcloud config set project "${MONITORED_PROJECT_ID}"
if ! gcloud beta run services list | grep -q "$SERVICE_NAME"; then
  printf "Service \"%s\" does not exist!\nExited with status code 1.\n" "$SERVICE_NAME"
  exit 1
fi
printf "Check successful!\n\n"

# set the scoping project and add the monitored project to the scoping project's metric scope
printf "Adding %s to metric scope in project %s...\n" "${MONITORED_PROJECT_ID}" "${SCOPING_PROJECT_ID}"
gcloud config set project "${SCOPING_PROJECT_ID}"
curl -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" -X POST \
  -d "{'name': 'locations/global/metricsScopes/${SCOPING_PROJECT_ID}/projects/${MONITORED_PROJECT_ID}'}" \
  https://monitoring.googleapis.com/v1/locations/global/metricsScopes/"${SCOPING_PROJECT_ID}"/projects
printf "%s successfully added to metric scope in scoping project %s!\n\n" "${MONITORED_PROJECT_ID}" "${SCOPING_PROJECT_ID}"

# create copy of json config file and substitute the required values
# - sed -i ''... for running on mac, remove '' if running on linux
cp ./cr_dashboard_config.json ./cr_dashboard_config_copy.json
sed -i '' "s/<service-name>/${SERVICE_NAME}/" ./cr_dashboard_config_copy.json
sed -i '' "s/<project-id>/${MONITORED_PROJECT_ID}/" ./cr_dashboard_config_copy.json
sed -i '' "s/<cr-region>/${REGION}/" ./cr_dashboard_config_copy.json

# create the dashboard
printf "Creating Cloud Run dashboard for %s service...\n" "${SERVICE_NAME}"
gcloud monitoring dashboards create --config-from-file=cr_dashboard_config_copy.json
printf "Cloud Run dashboard for %s service successfully created!\n\n" "${SERVICE_NAME}"

# clean up
rm cr_dashboard_config_copy.json

printf "Congratulations! A monitoring dashboard for Cloud Run service \"%s\" has been created in scoping project \"%s\".\n" \
  "${SERVICE_NAME}" "${SCOPING_PROJECT_ID}"
printf "Exit with status code 0.\n"
