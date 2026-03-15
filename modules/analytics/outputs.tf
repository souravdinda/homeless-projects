output "athena_workgroup_name" {
  value       = aws_athena_workgroup.analytics.name
  description = "The name of the Athena workgroup"
}

output "glue_database_name" {
  value       = aws_glue_catalog_database.e84_db.name
  description = "The name of the Glue data catalog"
}
