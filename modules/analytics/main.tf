# --- AWS Glue Catalog & Crawler ---
resource "aws_glue_catalog_database" "e84_db" {
  name = var.glue_database_name
}

resource "aws_iam_role" "glue_exec" {
  name = "${var.project_prefix}_glue_crawler_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "glue.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "glue_service" {
  role       = aws_iam_role.glue_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
}

resource "aws_iam_role_policy" "glue_s3_access" {
  name = "${var.project_prefix}_glue_s3"
  role = aws_iam_role.glue_exec.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action   = ["s3:GetObject", "s3:ListBucket"]
      Effect   = "Allow"
      Resource = [var.processed_bucket_arn, "${var.processed_bucket_arn}/*"]
    }]
  })
}

resource "aws_glue_crawler" "processed_data_crawler" {
  database_name = aws_glue_catalog_database.e84_db.name
  name          = "${var.project_prefix}_processed_data_crawler"
  role          = aws_iam_role.glue_exec.arn

  s3_target {
    path = "s3://${var.processed_bucket_id}/encounters_data"
  }

  schema_change_policy {
    update_behavior = "UPDATE_IN_DATABASE"
    delete_behavior = "LOG"
  }
}

# --- Amazon Athena ---
resource "aws_athena_workgroup" "analytics" {
  name          = var.athena_workgroup_name
  force_destroy = true
  
  configuration {
    result_configuration {
      output_location = "s3://${var.athena_results_bucket_id}/output/"
    }
  }
}

resource "aws_athena_named_query" "dashboard_aggregation" {
  name      = "${var.project_prefix}_shelter_anxiety_report"
  workgroup = aws_athena_workgroup.analytics.name
  database  = aws_glue_catalog_database.e84_db.name
  query     = <<EOF
SELECT 
  Shelter, 
  ROUND(AVG("Anxiety Lvl"), 2) as average_anxiety, 
  COUNT(*) as total_encounters
FROM 
  encounters_data
GROUP BY 
  Shelter
ORDER BY 
  average_anxiety DESC;
EOF
}
