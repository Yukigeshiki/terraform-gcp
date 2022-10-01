#!/bin/bash

set -e

# --- Adds Cloud Run service alerting policies (for a monitored project) inside a scoping project --- #

# Log in with `gcloud auth login` - user must have "Owner" role on the scoping project
# Create env vars:
# - export SERVICE_NAME=[cloud-run-service]
# - export REGION=[cloud-run-service-region]
# - export SCOPING_PROJECT_ID=[scoping-project-id]
# - export MONITORED_PROJECT_ID=[monitored-project-id]

# set monitored project and check service exists
printf "Checking %s service exists in project %s...\n" "${SERVICE_NAME}" "${MONITORED_PROJECT_ID}"
gcloud config set project "${MONITORED_PROJECT_ID}"
if ! gcloud beta run services list | grep -q "$SERVICE_NAME"; then
  printf "Service \"%s\" does not exist!\nExited with status code 1.\n" "$SERVICE_NAME"
  exit 1
fi
printf "Check successful!\n\n"

policy_file_names=("cr_service_cpu_usage_alert" "cr_service_memory_usage_alert" "cr_service_request_latency_alert")

printf "Setting scoping project...\n"
gcloud config set project "${SCOPING_PROJECT_ID}"
printf "\n"

for file_name in "${policy_file_names[@]}"; do

  json_file_name_copy="$file_name"_copy.json

  # create copy of json config file and substitute the required values
  # - sed -i ''... for running on mac, remove '' if running on linux
  cp ./"$file_name".json ./"$json_file_name_copy"
  sed -i '' "s/<service-name>/${SERVICE_NAME}/" ./"$json_file_name_copy"
  sed -i '' "s/<project-id>/${MONITORED_PROJECT_ID}/" ./"$json_file_name_copy"
  sed -i '' "s/<cr-region>/${REGION}/" ./"$json_file_name_copy"

  printf "Creating alerting policy for %s service running in region %s...\n" "${SERVICE_NAME}" "${REGION}"
  gcloud alpha monitoring policies create --policy-from-file="$json_file_name_copy"
  printf "Alerting policy for %s service successfully created!\n\n" "${SERVICE_NAME}"

  # clean up
  rm "$json_file_name_copy"

done

printf "Congratulations! Alerting policies for Cloud Run service \"%s\" have been created in scoping project \"%s\".\n" \
  "${SERVICE_NAME}" "${SCOPING_PROJECT_ID}"
printf "Exit with status code 0.\n"
