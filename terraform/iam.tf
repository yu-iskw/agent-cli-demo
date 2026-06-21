locals {
  agent_runtime_roles = [
    "roles/aiplatform.user",
    "roles/logging.logWriter",
    "roles/cloudtrace.agent",
    "roles/secretmanager.secretAccessor",
  ]
}

# Runtime permissions for each agent service account.
resource "google_project_iam_member" "agent_runtime" {
  for_each = {
    for pair in setproduct(keys(var.agent_sa_ids), local.agent_runtime_roles) :
    "${pair[0]}-${replace(pair[1], "/", "-")}" => {
      agent = pair[0]
      role  = pair[1]
    }
  }

  project = var.project_id
  role    = each.value.role
  member  = "serviceAccount:${google_service_account.agents[each.value.agent].email}"
}

# Operator can impersonate agent SAs for agents-cli deploy and platform ops.
resource "google_service_account_iam_member" "operator_impersonate_agents" {
  for_each = var.agent_sa_ids

  service_account_id = google_service_account.agents[each.key].name
  role               = "roles/iam.serviceAccountTokenCreator"
  member             = "serviceAccount:${google_service_account.operator.email}"
}

# Grant operator minimal deploy roles (scoped to project; tighten in production).
resource "google_project_iam_member" "operator_deploy" {
  for_each = toset([
    "roles/aiplatform.admin",
    "roles/iam.serviceAccountUser",
    "roles/storage.objectAdmin",
  ])

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.operator.email}"
}

# Demo persona groups: bind in M3 after creating real Google Groups in yexperiment.
# See terraform/policies/README.md and docs/guides/04-mesh-governance.md.
