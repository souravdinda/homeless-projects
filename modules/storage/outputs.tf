output "raw_bucket_id" {
  value       = aws_s3_bucket.raw_data.id
  description = "The name of the raw data bucket"
}

output "raw_bucket_arn" {
  value       = aws_s3_bucket.raw_data.arn
  description = "The ARN of the raw data bucket"
}

output "processed_bucket_id" {
  value       = aws_s3_bucket.processed_data.id
  description = "The name of the processed data bucket"
}

output "processed_bucket_arn" {
  value       = aws_s3_bucket.processed_data.arn
  description = "The ARN of the processed data bucket"
}

output "athena_results_bucket_id" {
  value       = aws_s3_bucket.athena_query_results.id
  description = "The name of the bucket for Athena query results"
}

output "athena_results_bucket_arn" {
  value       = aws_s3_bucket.athena_query_results.arn
  description = "The ARN of the bucket for Athena query results"
}
