variable "project_id" {
  description = "GCP project ID for the mesh demo."
  type        = string
  default     = "yexperiment"
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

# Demo group emails — replace with real Google Groups in yexperiment before M3.
variable "mesh_persona_groups" {
  description = "Google Group emails for governance demo personas."
  type        = map(string)
  default = {
    mesh-full-user   = "mesh-full-user@yexperiment.example"
    mesh-flight-user = "mesh-flight-user@yexperiment.example"
    mesh-hotel-user  = "mesh-hotel-user@yexperiment.example"
    mesh-deny-user   = "mesh-deny-user@yexperiment.example"
  }
}
