variable "name" {
  type        = string
  description = "Name prefix (e.g. <project>-<environment>) for the bucket and role."
}

variable "region" {
  type        = string
  description = "Region (used for the bucket and surfaced to the Velero BSL config)."
}

variable "tags" {
  type    = map(string)
  default = {}
}
