# --- S3 Buckets ---
resource "aws_s3_bucket" "raw_data" {
  bucket_prefix = "${var.project_prefix}-raw-data-"
  force_destroy = true
}

resource "aws_s3_bucket" "processed_data" {
  bucket_prefix = "${var.project_prefix}-processed-data-"
  force_destroy = true
}

resource "aws_s3_bucket" "athena_query_results" {
  bucket_prefix = "${var.project_prefix}-athena-results-"
  force_destroy = true
}
