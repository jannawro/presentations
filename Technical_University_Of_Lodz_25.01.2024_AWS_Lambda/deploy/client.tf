#========================================================================
// lambda setup
#========================================================================
resource "aws_s3_bucket" "client_lambda_bucket" {
  bucket_prefix = "client-lambda"
  force_destroy = true
}

data "archive_file" "client_zip" {
  type = "zip"

  source_dir  = "${path.module}/client"
  output_path = "${path.module}/client.zip"
}

resource "aws_s3_object" "client" {
  bucket = aws_s3_bucket.client_lambda_bucket.id

  key    = "client.zip"
  source = data.archive_file.client_zip.output_path

  etag = filemd5(data.archive_file.client_zip.output_path)
}

//Define lambda function
resource "aws_lambda_function" "client" {
  function_name = "client-${random_string.random.id}"
  description   = "client function"

  s3_bucket = aws_s3_bucket.client_lambda_bucket.id
  s3_key    = aws_s3_object.client.key

  runtime = "python3.9"
  handler = "app.lambda_handler"

  source_code_hash = data.archive_file.client_zip.output_base64sha256

  role = aws_iam_role.client_exec.arn

  environment {
    variables = {
      API_URL = "http://${aws_lb.load_balancer.dns_name}"
    }
  }
  depends_on = [aws_cloudwatch_log_group.client_lambda_logs]

}

resource "aws_cloudwatch_log_group" "client_lambda_logs" {
  name = "/aws/lambda/client-${random_string.random.id}"

  retention_in_days = var.lambda_log_retention
}

resource "aws_iam_role" "client_exec" {
  name = "client-exec"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Sid    = ""
      Principal = {
        Service = "lambda.amazonaws.com"
      }
      }
    ]
  })
}

resource "aws_iam_policy" "client_exec_role" {
  name = "client-exec-policy"

  policy = <<POLICY
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "cloudwatch:PutMetricData"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "logs:CreateLogGroup",
                "logs:CreateLogStream",
                "logs:PutLogEvents"
            ],
            "Resource": "*"
        }

    ]
}
POLICY
}

resource "aws_iam_role_policy_attachment" "client_policy" {
  role       = aws_iam_role.client_exec.name
  policy_arn = aws_iam_policy.client_exec_role.arn
}

#========================================================================
// events setup
#========================================================================
resource "aws_cloudwatch_event_rule" "client" {
  name = "client-${random_string.random.id}"

  depends_on = [
    aws_lambda_function.client,
  ]

  schedule_expression = "rate(1 minute)"
}

resource "aws_cloudwatch_event_target" "client" {
  target_id = "client-${random_string.random.id}"
  rule      = aws_cloudwatch_event_rule.client.name
  arn       = aws_lambda_function.client.arn
  input     = "{}"

  retry_policy {
    maximum_retry_attempts       = 2
    maximum_event_age_in_seconds = 60
  }
}

resource "aws_lambda_permission" "check_permission" {
  statement_id  = "client-${random_string.random.id}"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.client.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.client.arn
}
