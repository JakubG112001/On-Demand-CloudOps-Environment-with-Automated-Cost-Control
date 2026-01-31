# S3 bucket for static website
resource "aws_s3_bucket" "website" {
  bucket = "${var.project_name}-website-${random_id.bucket_suffix.hex}"
  
  tags = {
    Name        = "${var.project_name}-website"
    Environment = var.environment
  }
}

resource "random_id" "bucket_suffix" {
  byte_length = 4
}

resource "aws_s3_bucket_website_configuration" "website" {
  bucket = aws_s3_bucket.website.id
  
  index_document {
    suffix = "index.html"
  }
}

resource "aws_s3_bucket_public_access_block" "website" {
  bucket = aws_s3_bucket.website.id
  
  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_policy" "website" {
  bucket = aws_s3_bucket.website.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "PublicReadGetObject"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.website.arn}/*"
      }
    ]
  })
  
  depends_on = [aws_s3_bucket_public_access_block.website]
}

resource "aws_s3_object" "index" {
  bucket       = aws_s3_bucket.website.id
  key          = "index.html"
  source       = "${path.module}/../website/index.html"
  content_type = "text/html"
  etag         = filemd5("${path.module}/../website/index.html")
}

# DynamoDB table for session management
resource "aws_dynamodb_table" "sessions" {
  name           = "${var.project_name}-demo-sessions"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "sessionId"
  
  attribute {
    name = "sessionId"
    type = "S"
  }
  
  ttl {
    attribute_name = "ttl"
    enabled        = true
  }
  
  tags = {
    Name        = "${var.project_name}-sessions"
    Environment = var.environment
  }
}

# Lambda execution role
resource "aws_iam_role" "lambda_role" {
  name = "${var.project_name}-lambda-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "lambda_policy" {
  name = "${var.project_name}-lambda-policy"
  role = aws_iam_role.lambda_role.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "autoscaling:UpdateAutoScalingGroup",
          "autoscaling:DescribeAutoScalingGroups"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "rds:StartDBInstance",
          "rds:StopDBInstance",
          "rds:DescribeDBInstances"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "elasticloadbalancing:DescribeLoadBalancers"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "events:PutRule",
          "events:PutTargets",
          "events:RemoveTargets",
          "events:DeleteRule"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem",
          "dynamodb:GetItem",
          "dynamodb:UpdateItem",
          "dynamodb:Scan"
        ]
        Resource = aws_dynamodb_table.sessions.arn
      },
      {
        Effect = "Allow"
        Action = [
          "lambda:InvokeFunction"
        ]
        Resource = "*"
      }
    ]
  })
}

# Lambda functions
resource "aws_lambda_function" "start_infrastructure" {
  filename         = "start_infrastructure.zip"
  function_name    = "${var.project_name}-start-infrastructure"
  role            = aws_iam_role.lambda_role.arn
  handler         = "start_infrastructure.lambda_handler"
  runtime         = "python3.9"
  timeout         = 60
  
  depends_on = [data.archive_file.start_lambda_zip]
  
  tags = {
    Name        = "${var.project_name}-start-lambda"
    Environment = var.environment
  }
}

resource "aws_lambda_function" "stop_infrastructure" {
  filename         = "stop_infrastructure.zip"
  function_name    = "${var.project_name}-stop-infrastructure"
  role            = aws_iam_role.lambda_role.arn
  handler         = "stop_infrastructure.lambda_handler"
  runtime         = "python3.9"
  timeout         = 60
  
  depends_on = [data.archive_file.stop_lambda_zip]
  
  tags = {
    Name        = "${var.project_name}-stop-lambda"
    Environment = var.environment
  }
}

resource "aws_lambda_function" "check_status" {
  filename         = "check_status.zip"
  function_name    = "${var.project_name}-check-status"
  role            = aws_iam_role.lambda_role.arn
  handler         = "check_status.lambda_handler"
  runtime         = "python3.9"
  timeout         = 30
  
  depends_on = [data.archive_file.status_lambda_zip]
  
  tags = {
    Name        = "${var.project_name}-status-lambda"
    Environment = var.environment
  }
}

resource "aws_lambda_function" "get_metrics" {
  filename         = "get_metrics.zip"
  function_name    = "${var.project_name}-get-metrics"
  role            = aws_iam_role.lambda_role.arn
  handler         = "get_metrics.lambda_handler"
  runtime         = "python3.9"
  timeout         = 30
  
  depends_on = [data.archive_file.metrics_lambda_zip]
  
  tags = {
    Name        = "${var.project_name}-metrics-lambda"
    Environment = var.environment
  }
}

resource "aws_lambda_function" "simulate_chaos" {
  filename         = "simulate_chaos.zip"
  function_name    = "${var.project_name}-simulate-chaos"
  role            = aws_iam_role.lambda_role.arn
  handler         = "simulate_chaos.lambda_handler"
  runtime         = "python3.9"
  timeout         = 30
  
  depends_on = [data.archive_file.chaos_lambda_zip]
  
  tags = {
    Name        = "${var.project_name}-chaos-lambda"
    Environment = var.environment
  }
}

resource "aws_lambda_function" "get_analytics" {
  filename         = "get_analytics.zip"
  function_name    = "${var.project_name}-get-analytics"
  role            = aws_iam_role.lambda_role.arn
  handler         = "get_analytics.lambda_handler"
  runtime         = "python3.9"
  timeout         = 30
  
  depends_on = [data.archive_file.analytics_lambda_zip]
  
  tags = {
    Name        = "${var.project_name}-analytics-lambda"
    Environment = var.environment
  }
}

# Lambda deployment packages
data "archive_file" "start_lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/../lambda/start_infrastructure.py"
  output_path = "start_infrastructure.zip"
}

data "archive_file" "stop_lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/../lambda/stop_infrastructure.py"
  output_path = "stop_infrastructure.zip"
}

data "archive_file" "status_lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/../lambda/check_status.py"
  output_path = "check_status.zip"
}

data "archive_file" "metrics_lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/../lambda/get_metrics.py"
  output_path = "get_metrics.zip"
}

data "archive_file" "chaos_lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/../lambda/simulate_chaos.py"
  output_path = "simulate_chaos.zip"
}

data "archive_file" "analytics_lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/../lambda/get_analytics.py"
  output_path = "get_analytics.zip"
}

# API Gateway
resource "aws_api_gateway_rest_api" "demo_api" {
  name = "${var.project_name}-demo-api"
  
  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

# API Gateway resources and methods
resource "aws_api_gateway_resource" "start" {
  rest_api_id = aws_api_gateway_rest_api.demo_api.id
  parent_id   = aws_api_gateway_rest_api.demo_api.root_resource_id
  path_part   = "start"
}

resource "aws_api_gateway_resource" "stop" {
  rest_api_id = aws_api_gateway_rest_api.demo_api.id
  parent_id   = aws_api_gateway_rest_api.demo_api.root_resource_id
  path_part   = "stop"
}

resource "aws_api_gateway_resource" "status" {
  rest_api_id = aws_api_gateway_rest_api.demo_api.id
  parent_id   = aws_api_gateway_rest_api.demo_api.root_resource_id
  path_part   = "status"
}

# POST /start
resource "aws_api_gateway_method" "start_post" {
  rest_api_id   = aws_api_gateway_rest_api.demo_api.id
  resource_id   = aws_api_gateway_resource.start.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "start_integration" {
  rest_api_id = aws_api_gateway_rest_api.demo_api.id
  resource_id = aws_api_gateway_resource.start.id
  http_method = aws_api_gateway_method.start_post.http_method
  
  integration_http_method = "POST"
  type                   = "AWS_PROXY"
  uri                    = aws_lambda_function.start_infrastructure.invoke_arn
}

# POST /stop
resource "aws_api_gateway_method" "stop_post" {
  rest_api_id   = aws_api_gateway_rest_api.demo_api.id
  resource_id   = aws_api_gateway_resource.stop.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "stop_integration" {
  rest_api_id = aws_api_gateway_rest_api.demo_api.id
  resource_id = aws_api_gateway_resource.stop.id
  http_method = aws_api_gateway_method.stop_post.http_method
  
  integration_http_method = "POST"
  type                   = "AWS_PROXY"
  uri                    = aws_lambda_function.stop_infrastructure.invoke_arn
}

# GET /status
resource "aws_api_gateway_method" "status_get" {
  rest_api_id   = aws_api_gateway_rest_api.demo_api.id
  resource_id   = aws_api_gateway_resource.status.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "status_integration" {
  rest_api_id = aws_api_gateway_rest_api.demo_api.id
  resource_id = aws_api_gateway_resource.status.id
  http_method = aws_api_gateway_method.status_get.http_method
  
  integration_http_method = "POST"
  type                   = "AWS_PROXY"
  uri                    = aws_lambda_function.check_status.invoke_arn
}

# CORS for all methods
resource "aws_api_gateway_method" "start_options" {
  rest_api_id   = aws_api_gateway_rest_api.demo_api.id
  resource_id   = aws_api_gateway_resource.start.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "start_options_integration" {
  rest_api_id = aws_api_gateway_rest_api.demo_api.id
  resource_id = aws_api_gateway_resource.start.id
  http_method = aws_api_gateway_method.start_options.http_method
  type        = "MOCK"
  
  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

resource "aws_api_gateway_method_response" "start_options_response" {
  rest_api_id = aws_api_gateway_rest_api.demo_api.id
  resource_id = aws_api_gateway_resource.start.id
  http_method = aws_api_gateway_method.start_options.http_method
  status_code = "200"
  
  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
}

resource "aws_api_gateway_integration_response" "start_options_integration_response" {
  rest_api_id = aws_api_gateway_rest_api.demo_api.id
  resource_id = aws_api_gateway_resource.start.id
  http_method = aws_api_gateway_method.start_options.http_method
  status_code = aws_api_gateway_method_response.start_options_response.status_code
  
  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "method.response.header.Access-Control-Allow-Methods" = "'GET,OPTIONS,POST,PUT'"
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }
}

# API Gateway deployment
resource "aws_api_gateway_deployment" "demo_deployment" {
  depends_on = [
    aws_api_gateway_integration.start_integration,
    aws_api_gateway_integration.stop_integration,
    aws_api_gateway_integration.status_integration,
  ]
  
  rest_api_id = aws_api_gateway_rest_api.demo_api.id
  stage_name  = "prod"
}

# Lambda permissions for API Gateway
resource "aws_lambda_permission" "start_api_gateway" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.start_infrastructure.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.demo_api.execution_arn}/*/*"
}

resource "aws_lambda_permission" "stop_api_gateway" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.stop_infrastructure.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.demo_api.execution_arn}/*/*"
}

resource "aws_lambda_permission" "status_api_gateway" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.check_status.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.demo_api.execution_arn}/*/*"
}

# EventBridge permissions for Lambda
resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.stop_infrastructure.function_name
  principal     = "events.amazonaws.com"
}