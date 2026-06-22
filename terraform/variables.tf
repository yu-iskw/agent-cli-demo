variable "project_id" {
  description = "GCP project ID for the mesh demo."
  type        = string
}

variable "region" {
  description = "GCP region for Agent Platform resources."
  type        = string
  default     = "asia-northeast1"
}

variable "operator_sa_id" {
  description = "Service account ID for deploy/ops (impersonated by humans/CI)."
  type        = string
  default     = "agent-operator-sa"
}

variable "agent_sa_ids" {
  description = "Runtime service account IDs per mesh agent."
  type        = map(string)
  default = {
    trip-planner      = "trip-planner-sa"
    flight-researcher = "flight-researcher-sa"
    hotel-researcher  = "hotel-researcher-sa"
  }
}

# Demo group emails — replace with real Google Groups before M3 persona tests.
variable "mesh_persona_groups" {
  description = "Google Group emails for governance demo personas."
  type        = map(string)
  default = {
    mesh-full-user   = "mesh-full-user@example.com"
    mesh-flight-user = "mesh-flight-user@example.com"
    mesh-hotel-user  = "mesh-hotel-user@example.com"
    mesh-deny-user   = "mesh-deny-user@example.com"
  }
}
