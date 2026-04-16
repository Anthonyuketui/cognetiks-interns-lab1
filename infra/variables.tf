variable "resource_group_name" {
  default = "cognetiksRG"
}

variable "location" {
  default = "westus2"
}

variable "acr_name" {
  default = "cogneticsregistry"
}

variable "image_name" {
  default = "lab1-starter-app"
}

variable "image_tag" {
  default = "v1.4"
}

variable "app_name" {
  default = "lab1-anthony"
}

variable "log_analytics_name" {
  description = "Name of the Log Analytics workspace"
  default     = "shredvarsity-logs"
}

variable "app_display_name" {
  description = "Display name shown on the homepage"
}

variable "intern_name" {
  description = "Intern's full name"
}

variable "cloud_platform" {
  description = "Cloud platform (AWS/Azure)"
}

variable "environment" {
  default = "dev"
}

variable "app_status" {
  default = "healthy"
}
