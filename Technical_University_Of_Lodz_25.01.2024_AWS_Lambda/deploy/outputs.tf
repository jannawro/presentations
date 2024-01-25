# Output value definitions


output "server_lambda_log_group" {
  description = "Name of the CloudWatch logs group for the lambda function"
  value       = aws_cloudwatch_log_group.server_logs.id
}

output "lambda_log_group" {
  description = "Name of the CloudWatch logs group for the lambda function"
  value       = aws_cloudwatch_log_group.client_lambda_logs.id
}

output "api_url" {
  value = "http://${aws_lb.load_balancer.dns_name}"
}
