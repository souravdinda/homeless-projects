module "storage" {
  source         = "./modules/storage"
  project_prefix = var.project_prefix
}

module "processing" {
  source               = "./modules/processing"
  project_prefix       = var.project_prefix
  raw_bucket_id        = module.storage.raw_bucket_id
  raw_bucket_arn       = module.storage.raw_bucket_arn
  processed_bucket_id  = module.storage.processed_bucket_id
  processed_bucket_arn = module.storage.processed_bucket_arn
}

module "analytics" {
  source                   = "./modules/analytics"
  project_prefix           = var.project_prefix
  glue_database_name       = var.glue_database_name
  athena_workgroup_name    = var.athena_workgroup_name
  processed_bucket_id      = module.storage.processed_bucket_id
  processed_bucket_arn     = module.storage.processed_bucket_arn
  athena_results_bucket_id = module.storage.athena_results_bucket_id
}

# Outputs
output "raw_bucket_name" {
  value = module.storage.raw_bucket_id
}

output "processed_bucket_name" {
  value = module.storage.processed_bucket_id
}

output "athena_workgroup" {
  value = module.analytics.athena_workgroup_name
}
