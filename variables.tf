variable "aws_region" {
  type        = string
  description = "AWS region to deploy to"
  default     = "us-east-1"
}

variable "project_prefix" {
  type        = string
  description = "Prefix for all resources created by this Terraform"
}

variable "glue_database_name" {
  type        = string
  description = "Name for the AWS Glue Data Catalog Database"
}

variable "athena_workgroup_name" {
  type        = string
  description = "Name for the Athena Analytics Workgroup"
}
