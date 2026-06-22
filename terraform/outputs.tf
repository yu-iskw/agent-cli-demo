output "operator_service_account_email" {
  description = "Impersonate this SA for agents-cli deploy (GOOGLE_IMPERSONATE_SERVICE_ACCOUNT)."
  value       = google_service_account.operator.email
}

output "agent_service_account_emails" {
  description = "Runtime SAs — pass to agents-cli deploy --service-account."
  value = {
    for name, sa in google_service_account.agents :
    name => sa.email
  }
}

output "project_id" {
  value = var.project_id
}

output "region" {
  value = var.region
}
