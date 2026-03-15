output "lambda_arn" {
  value       = aws_lambda_function.data_processor.arn
  description = "The ARN of the Lambda function"
}
