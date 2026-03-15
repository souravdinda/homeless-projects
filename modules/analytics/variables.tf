variable "project_prefix" {
  type        = string
  description = "Prefix for resources"
}

variable "glue_database_name" {
  type        = string
  description = "Name for the Glue Database"
}

variable "athena_workgroup_name" {
  type        = string
  description = "Name for the Athena Analytics Workgroup"
}

variable "processed_bucket_id" {
  type        = string
  description = "The name of the processed data bucket"
}

variable "processed_bucket_arn" {
  type        = string
  description = "The ARN of the processed data bucket"
}

variable "athena_results_bucket_id" {
  type        = string
  description = "The name of the bucket for Athena query results"
}
