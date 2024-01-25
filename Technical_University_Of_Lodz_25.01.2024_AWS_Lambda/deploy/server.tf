#========================================================================
// database setup
#========================================================================
resource "aws_dynamodb_table" "movie_table" {
  name           = var.dynamodb_table
  billing_mode   = "PROVISIONED"
  read_capacity  = 20
  write_capacity = 20
  hash_key       = "year"
  range_key      = "title"

  attribute {
    name = "year"
    type = "N"
  }

  attribute {
    name = "title"
    type = "S"
  }
}

#========================================================================
// lambda setup
#========================================================================
resource "aws_s3_bucket" "server_bucket" {
  bucket_prefix = "movies-server-lambda"
  force_destroy = true
}

data "archive_file" "server_zip" {
  type = "zip"

  source_dir  = "${path.module}/server"
  output_path = "${path.module}/server.zip"
}

resource "aws_s3_object" "server" {
  bucket = aws_s3_bucket.server_bucket.id

  key    = "server.zip"
  source = data.archive_file.server_zip.output_path

  etag = filemd5(data.archive_file.server_zip.output_path)
}

//Define lambda function
resource "aws_lambda_function" "server" {
  function_name = "movies-server-${random_string.random.id}"
  description   = "server function"

  s3_bucket = aws_s3_bucket.server_bucket.id
  s3_key    = aws_s3_object.server.key

  runtime = "python3.9"
  handler = "app.lambda_handler"

  source_code_hash = data.archive_file.server_zip.output_base64sha256

  role = aws_iam_role.server_exec.arn

  environment {
    variables = {
      DDB_TABLE = var.dynamodb_table
    }
  }
  depends_on = [aws_cloudwatch_log_group.server_logs]

}

resource "aws_cloudwatch_log_group" "server_logs" {
  name = "/aws/lambda/movies-server-${random_string.random.id}"

  retention_in_days = var.lambda_log_retention
}

resource "aws_iam_role" "server_exec" {
  name = "server-exec"

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

resource "aws_iam_policy" "server_exec_role" {
  name = "server-exec-policy"

  policy = <<POLICY
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "dynamodb:GetItem",
                "dynamodb:PutItem",
                "dynamodb:UpdateItem",
                "dynamodb:Scan"
            ],
            "Resource": "arn:aws:dynamodb:*:*:table/${var.dynamodb_table}"
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

resource "aws_iam_role_policy_attachment" "server_policy" {
  role       = aws_iam_role.server_exec.name
  policy_arn = aws_iam_policy.server_exec_role.arn
}

#========================================================================
// Application load balancer setup
#========================================================================

# Create AWS VPC 
resource "aws_vpc" "vpc" {
  cidr_block = var.vpc_cidr
}

# Create public subnet 1
resource "aws_subnet" "public_subnet1" {
  cidr_block        = "10.0.1.0/24"
  vpc_id            = aws_vpc.vpc.id
  availability_zone = "${var.region}a"
  tags = {
    Name = "Subnet for ${var.region}a"
  }
}

# Create public subnet 2
resource "aws_subnet" "public_subnet2" {
  cidr_block        = "10.0.2.0/24"
  vpc_id            = aws_vpc.vpc.id
  availability_zone = "${var.region}b"
  tags = {
    Name = "Subnet for ${var.region}b"
  }
}

# Create a route table 
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "public_rt"
  }
}

# Associate the route table with public subnet 1
resource "aws_route_table_association" "public_rt_table_a" {
  subnet_id      = aws_subnet.public_subnet1.id
  route_table_id = aws_route_table.public_rt.id
}

# Associate the route table with public subnet 2
resource "aws_route_table_association" "public_rt_table_b" {
  subnet_id      = aws_subnet.public_subnet2.id
  route_table_id = aws_route_table.public_rt.id
}

# Create an Internet Gateway
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.vpc.id
}

# Create a security group for application load balancer
resource "aws_security_group" "load_balancer_sg" {
  name   = "myLoadBalancerSG"
  vpc_id = aws_vpc.vpc.id
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "myLoadBalancerSG"
  }
}

# Create the application load balancer
resource "aws_lb" "load_balancer" {
  name               = "myLoadBalancer"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.load_balancer_sg.id]
  subnets            = [aws_subnet.public_subnet1.id, aws_subnet.public_subnet2.id]
  tags = {
    Name = "myLoadBalancer"
  }
}

# Create the ALB listener with the target group.
resource "aws_lb_listener" "listener" {
  load_balancer_arn = aws_lb.load_balancer.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.target_group.arn
  }
}

# Create the ALB target group for Lambda
resource "aws_lb_target_group" "target_group" {
  name        = "myLoadBalancerTargets"
  target_type = "lambda"
}

# Attach the ALB target group to the Lambda Function
resource "aws_lb_target_group_attachment" "target_group_attachment" {
  target_group_arn = aws_lb_target_group.target_group.arn
  target_id        = aws_lambda_function.server.arn
}

# Allow the application load balancer to access Lambda Function
resource "aws_lambda_permission" "with_lb" {
  statement_id  = "AllowExecutionFromlb"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.server.arn
  principal     = "elasticloadbalancing.amazonaws.com"
  source_arn    = aws_lb_target_group.target_group.arn
}
