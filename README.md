# Terraform Admin Project Setup

### Project and APIs

The **tf-admin** project must be created and the following APIs enabled:

- Cloud Billing API (cloudbilling.googleapis.com)
- Cloud Resource Manager API (cloudresourcemanager.googleapis.com)
- Cloud SQL Admin API (sqladmin.googleapis.com)
- Compute Engine API (compute.googleapis.com)
- Networking API (servicenetworking.googleapis.com)
- Cloud Build API (cloudbuild.googleapis.com)
- Cloud Identity ID API (cloudidentity.googleapis.com)
- IAM API (iam.googleapis.com)

### Terraform Admin Custom Role

At the Org level the **Terraform Admin** custom role has must be created with the following permissions:

- billing.accounts.get
- billing.resourceAssociations.create
- billing.resourceAssociations.list
- cloudsql.databases.create
- cloudsql.instances.create
- cloudsql.users.create
- compute.acceleratorTypes.get
- compute.acceleratorTypes.list
- compute.addresses.create
- compute.addresses.createInternal
- compute.addresses.delete
- compute.addresses.deleteInternal
- compute.addresses.get
- compute.addresses.list
- compute.addresses.setLabels
- compute.addresses.use
- compute.firewalls.delete
- compute.firewalls.get
- compute.firewalls.list
- compute.globalOperations.get
- compute.globalOperations.list
- compute.instances.get
- compute.networks.create
- compute.networks.delete
- compute.networks.get
- compute.networks.updatePolicy
- compute.organizations.disableXpnHost
- compute.organizations.disableXpnResource
- compute.organizations.enableXpnHost
- compute.organizations.enableXpnResource
- compute.projects.get
- compute.subnetworks.get
- compute.subnetworks.getIamPolicy
- compute.subnetworks.setIamPolicy
- logging.sinks.create
- logging.sinks.get
- logging.sinks.update
- monitoring.timeSeries.list
- resourcemanager.folders.create
- resourcemanager.folders.get
- resourcemanager.folders.list
- resourcemanager.organizations.get
- resourcemanager.organizations.getIamPolicy
- resourcemanager.projects.create
- resourcemanager.projects.createBillingAssignment
- resourcemanager.projects.deleteBillingAssignment
- resourcemanager.projects.get
- resourcemanager.projects.getIamPolicy
- resourcemanager.projects.list
- resourcemanager.projects.setIamPolicy
- serviceusage.operations.get
- serviceusage.operations.list
- serviceusage.quotas.get
- serviceusage.services.get
- serviceusage.services.list
- serviceusage.services.use
- storage.buckets.create
- storage.buckets.delete
- storage.buckets.get
- storage.buckets.getIamPolicy
- storage.buckets.list
- storage.buckets.update
- storage.objects.create
- storage.objects.delete
- storage.objects.get
- storage.objects.getIamPolicy
- Storage.objects.list

### Cloud Build User Generated Service Account

In the **tf-admin** project a service account **tf-sa-gcp** must be created and assigned the **Terraform Admin** custom role at the Org level.

### Cloud Build Trigger

GitOps style Terraform deployments can be set up to fit Google best practices by following [this](https://cloud.google.com/architecture/managing-infrastructure-as-code) GCP documentation.

# Infrastructure

### Environments

The Terraform code describes three environments; development, test and production. Each of these environments has a top level folder which contains all other environment resources (subfolders and projects).

### Networking

Each environment has a host project, this project contains a host VPC network with default subnets for all available regions. All other projects inside the environment are service projects connected to this host VPC.

### Administration

Each host project is considered a scoping project and contains consolidated monitoring, logging and alerting (including alerting channels) for its environment; with service projects added as monitored projects inside this scope. Individual Cloud Run projects are assigned a Service Owner (this can be a product group or an individual user). The Service Owner has the permissions needed to do general development tasks. Each project also has a log archive bucket which has a configurable retention period (in most cases it will be 12 months in accordance with the "System Access & Authorization Control Policy").

# User Groups

There are both team groups and product team groups.

## Team Groups

### Engineering Team (eng@company.com)

This group is for all engineers at the company. The below roles are assigned to this group at each environment's top level folder.

**Development/Test:**

- Logs View Accessor
- Viewer
- IAP Tunnel resource Accessor
- IAM Service Account User

**Production:**

- Browser
- Cloud Build Viewer
- Logs View Accessor
- Logs Viewer
- Monitoring Viewer
- Cloud Run Viewer
- Error Reporting Viewer
- Cloud Memorystore Redis Viewer

### Engineering Team Elevated (eng-el@company.com)

This group is for engineers with elevated privileges. The below roles are assigned to this group at each environment's top level folder.

**Production:**

- Viewer
- IAP Tunnel resource Accessor
- IAM Service Account User

### Cloud Operations Team (cloudops@company.com)

This group is to give permissions to the CloudOps team at each environment's top level folder.

**Development/Test/Production**

- Compute Load Balancer Admin
- Monitoring Admin
- Logging Admin
- Error reporting Admin
- Secret manager Admin
- Cloud Build Editor
- Cloud Scheduler Admin
- Cloud Run Admin
- Compute Security Admin
- Service Usage Consumer
- IAP Tunnel resource Accessor
- IAM Service Account User

## Product Groups

These groups are for specific product teams and can be used as Service Owners in Cloud Run projects.

# Cloud Run Deployments

### Deployment

Cloud Run services are deployed using a combination of GitHub Actions and Cloud Build. GitHub Actions is responsible for running tests and calling Cloud Build. Cloud Build is then responsible for building and deploying to Cloud Run. This was done for security and ease of setup reasons as Cloud Build is designed to deploy GCP resources specifically while GitHub Actions would need extra permissions and setup to complete the same jobs.

### Service Accounts

**github-actions-sa**: This service account is used to give GitHub Actions permission to call Cloud Build. Each project will have this service account and roles are assigned at the project level.

Roles:

- Cloud Build Service Agent

**cloud-run-sa**: This service account is assigned to your Cloud Run services - if this is not done, Cloud Run will use the default compute service account. Using the default compute service account can be dangerous as it has high level privileges. Each project will have this service account and roles are assigned at the project level.

Roles:

- Cloud Run Invoker
- Cloud Run SA Core Permissions (custom role)

**[project-number]@cloudbuild.gserviceaccount.com**: This is the default Cloud Build service account that is created when the Cloud Build API is enabled.

Roles:

- Cloud Build Service Account
- Cloud Build SA Core Permissions (custom role)

### Custom Roles

The **Cloud Run SA Core Permissions** custom role contains the following permissions:

- resourcemanager.projects.get
- resourcemanager.projects.list
- Secretmanager.versions.access

The **Cloud Build SA Core Permissions** custom role contains the following permissions:

- cloudscheduler.jobs.create
- cloudscheduler.jobs.enable
- cloudscheduler.jobs.list
- cloudscheduler.jobs.update
- cloudscheduler.locations.list
- iam.serviceAccounts.actAs
- iam.serviceAccounts.get
- iam.serviceAccounts.list
- recommender.locations.get
- recommender.locations.list
- resourcemanager.projects.get
- resourcemanager.projects.list
- run.configurations.get
- run.configurations.list
- run.jobs.create
- run.jobs.delete
- run.jobs.get
- run.jobs.getIamPolicy
- run.jobs.list
- run.jobs.setIamPolicy
- run.jobs.update
- run.locations.list
- run.operations.delete
- run.operations.get
- run.operations.list
- run.revisions.delete
- run.revisions.get
- run.revisions.list
- run.routes.get
- run.routes.list
- run.services.create
- run.services.createTagBinding
- run.services.delete
- run.services.deleteTagBinding
- run.services.get
- run.services.getIamPolicy
- run.services.list
- run.services.listEffectiveTags
- run.services.listTagBindings
- run.services.setIamPolicy
- run.services.update
- secretmanager.versions.access

# Terraform Modules

### compute

**iap_and_nat:** The iap_and_nat module creates the needed resources for an internal VM. These resources are a Cloud Nat Subnetwork, Cloud Nat Router, Cloud Nat Router Config and an allow ingress from IAP on port 22 firewall rule. These resources give an internal VM access to the internet.

### db

**shared_redis_instance:** The shared_redis_instance module creates an instance of a Memorystore for Redis DB that is connected to the shared VPC network - this makes it possible for any service project on the shared VPC to connect to it.

### iam

**core_service_accounts:** The core_service_accounts module creates the needed service accounts for Cloud Run and GitHub actions, then assigns their IAM roles. It is used by project modules and uses the service_account module.

**group:** The group module creates a group and assigns members to it.

**service_account:** The service_account module creates a service account then assigns it IAM roles. Its main use is in the core_service_accounts module.

**service_owner:** The service_owner module assigns roles to either a group or a single user. These roles give the group/user permissions relating to common development activities. It also creates an email notification channel for one or more users which can be used to send Cloud Run error notifications. The roles assigned are:

- Cloud Run Developer
- Secret Manager Admin
- Cloud Scheduler Admin

### network

**backend_security_policies:** The backend_security_policies module creates Cloud Armor network security rules that are used with an HTTPS load balancer backend.

### operations

**log_archive:** The log_archive module creates a storage bucket of type `ARCHIVE`, it then creates a logging sink to route logs to this bucket for long term storage. The bucket has a retention policy that is configurable depending on how long logs must be kept. There is also a configurable logging filter so that resource specific logs for a project can be archived.

### projects

**host_project:** The host project holds the host VPC network. It is also where a serverless connector will be created for Cloud Run to access resources on the internal VPC network, eg. Cloud SQL. Consolidated logging/monitoring/alerting is also maintained in this project, but it is set up outside of Terraform. Finally, a VM is created here for CLI access (over SSH) to resources on the internal network, eg. a shared Redis db.

**Template Projects:**

**shared_redis:** This module creates a project with a Memorystore for Redis DB connected to the shared VPC network (see shared_redis_instance module above for more details).

**cloud_run:** This module creates a project with all the resources needed to deploy Cloud Run services.

# Bash Scripts

All bash scripts include instructions for needed dependencies and environment variables.

**cr_load_balancer.sh:** The cr_load_balancer script creates an HTTP(S) load balancer for a Cloud Run service as well as provisions a Google managed certificate for it. The IP address for the load balancer can then be used to create an A record with the subdomain for the service in Cloudflare. Cloud Armor security rules are also added to the load balancer backend.

**cr_monitoring_dashboard.sh:** The cr_monitoring_dashboard script adds a monitored project (the project running the Cloud Run service) to a scoping project and uses the cr_dashboard_config.json file to create a Cloud Run monitoring dashboard in the scoping projects metric scope.

**cr_migrate_traffic.sh:** The cr_migrate_traffic script migrates 100% of traffic to (depending on user input) either the latest or a named Cloud Run revision.

**cr_alerting.sh:** The cr_alerting script uses the cr_service_cpu_usage_alert.json, cr_service_memory_usage_alert.json and cr_service_request_latency_alert.json files to create alerting policies. Alerting channels are then added to these policies using the console.

**add_secrets_to_gcp.sh:** The add_secrets_to_gcp scipt uses a .env file to add secrets and config to GCP Secret Manager.
