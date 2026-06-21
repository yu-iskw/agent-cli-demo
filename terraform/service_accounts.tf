resource "google_service_account" "operator" {
  account_id   = var.operator_sa_id
  display_name = "Agent mesh operator (deploy/impersonation)"
  project      = var.project_id
}

resource "google_service_account" "agents" {
  for_each = var.agent_sa_ids

  account_id   = each.value
  display_name = "Runtime SA for ${each.key}"
  project      = var.project_id
}
