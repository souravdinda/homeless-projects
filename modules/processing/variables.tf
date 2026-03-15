variable "project_prefix" {
  type        = string
  description = "Prefix for resources"
}

variable "raw_bucket_id" {
  type        = string
  description = "The name of the raw data bucket"
}

variable "raw_bucket_arn" {
  type        = string
  description = "The ARN of the raw data bucket"
}

variable "processed_bucket_id" {
  type        = string
  description = "The name of the processed data bucket"
}

variable "processed_bucket_arn" {
  type        = string
  description = "The ARN of the processed data bucket"
}
