# --- CloudWatch Logs ---
resource "aws_cloudwatch_log_group" "lambda_log_group" {
  name              = "/aws/lambda/${var.project_prefix}-data-processor"
  retention_in_days = 14
}

# --- Lambda Data Processor ---
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/../../lambda/processor.py"
  output_path = "${path.module}/../../lambda/processor.zip"
}

resource "aws_iam_role" "lambda_exec" {
  name = "${var.project_prefix}_data_processor_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "lambda_s3_access" {
  name = "${var.project_prefix}_lambda_policy"
  role = aws_iam_role.lambda_exec.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action   = ["s3:GetObject", "s3:ListBucket"]
        Effect   = "Allow"
        Resource = [var.raw_bucket_arn, "${var.raw_bucket_arn}/*"]
      },
      {
        Action   = ["s3:PutObject", "s3:PutObjectAcl"]
        Effect   = "Allow"
        Resource = ["${var.processed_bucket_arn}/*"]
      },
      {
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Effect   = "Allow"
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Action   = ["glue:StartCrawler"]
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })
}

resource "aws_lambda_function" "data_processor" {
  filename         = data.archive_file.lambda_zip.output_path
  function_name    = "${var.project_prefix}-data-processor"
  role             = aws_iam_role.lambda_exec.arn
  handler          = "processor.lambda_handler"
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  runtime          = "python3.12"
  timeout          = 120
  memory_size      = 512

  layers = ["arn:aws:lambda:us-east-1:336392948345:layer:AWSSDKPandas-Python312:12"]

  environment {
    variables = {
      RAW_BUCKET       = var.raw_bucket_id
      PROCESSED_BUCKET = var.processed_bucket_id
      CRAWLER_NAME     = "${var.project_prefix}_processed_data_crawler"
    }
  }

  depends_on = [aws_cloudwatch_log_group.lambda_log_group]
}

# --- S3 Event Notification to trigger Lambda ---
resource "aws_lambda_permission" "allow_s3" {
  statement_id  = "AllowExecutionFromS3Bucket"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.data_processor.arn
  principal     = "s3.amazonaws.com"
  source_arn    = var.raw_bucket_arn
}

resource "aws_s3_bucket_notification" "raw_bucket_notification" {
  bucket = var.raw_bucket_id

  lambda_function {
    lambda_function_arn = aws_lambda_function.data_processor.arn
    events              = ["s3:ObjectCreated:*"]
    filter_suffix       = ".csv"
  }

  depends_on = [aws_lambda_permission.allow_s3]
}

# --- CloudWatch Alarms ---
resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  alarm_name          = "${var.project_prefix}-processor-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = "60"
  statistic           = "Sum"
  threshold           = "0"
  alarm_description   = "This metric monitors Lambda execution errors (e.g. bad CSV format)."

  dimensions = {
    FunctionName = aws_lambda_function.data_processor.function_name
  }
}
