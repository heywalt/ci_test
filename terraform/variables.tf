variable "db_backup_enabled" {
  type    = bool
  default = true
}

variable "image" {
  type    = string
  default = "us-east5-docker.pkg.dev/heywalt/heywalt/walt-ui"
}

variable "image_tag" {
  type    = string
  default = "latest"
}

variable "project_id" {
  type    = string
  default = "heywalt"
}

variable "region" {
  type    = string
  default = "us-east5"
}
