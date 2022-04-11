
provider "aws" {
  region = "us-east-1"
}

resource "aws_iam_policy" "lambda_policy" {
  name        = "lambda_policy"
  description = "AWS IAM Policy for managing aws lambda role"
  policy      = file("${path.module}/../iam-roles/lambda-policy.json")
}

resource "aws_iam_role" "lambda_role" {
  name               = "lambda_role"
  assume_role_policy = file("${path.module}/../iam-roles/lambda-assume-policy.json")
}

resource "aws_iam_role_policy_attachment" "attach_iam_policy_to_iam_role" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_policy.arn
}


locals {
  ecr_images = [
    {
      name            = "admin_boundary"
      container_image = "670119057264.dkr.ecr.us-east-1.amazonaws.com/etl_lambda_container:v1",
      environment_vars = {
        SHAPEFILE_ZIP_URL = "https://raw.githubusercontent.com/wmgeolab/geoBoundaries/729d59ed25f7bcc7664fc6ca58755b4e8567e80c/releaseData/gbOpen/UKR/ADM0/geoBoundaries-UKR-ADM0-all.zip"
        S3_PATH           = "s3://rub21/test_mercy"
        COUNTRY           = "UKR",
      },
      input = <<JSON
          {"function": "admin_boundaries"}
          JSON
    }
  ]
}

# ############################################################
# ###### Create multiple lambda functions from  containers
# ############################################################

resource "aws_lambda_function" "lambda_functions" {
  for_each      = { for cj in local.ecr_images : cj.container_image => cj }
  role          = aws_iam_role.lambda_role.arn
  image_uri     = each.value.container_image
  function_name = each.value.name
  package_type  = "Image"
  environment {
    variables = each.value.environment_vars
  }
  depends_on = [aws_iam_role_policy_attachment.attach_iam_policy_to_iam_role]
}

# resource "aws_lambda_invocation" "lambda_functions_invocation" {
#   for_each      = { for cj in local.ecr_images : cj.container_image => cj }
#   function_name = each.value.name
#   triggers = {
#     redeployment = sha1(jsonencode([
#       each.value.environment_vars
#     ]))
#   }
#   input = each.value.input
# }

# resource "aws_cloudwatch_event_rule" "cron_job_lambda" {
#   name                = "cron_job_lambda"
#   description         = "Fires every five minutes"
#   schedule_expression = "rate(5 minutes)"
# }

# resource "aws_cloudwatch_event_target" "check_foo_every_one_minute" {
#   for_each  = aws_lambda_function.lambda_functions
#   rule      = aws_cloudwatch_event_rule.cron_job_lambda.name
#   target_id = each.value.function_name
#   arn       = each.value.arn
# }

# resource "aws_lambda_permission" "allow_cloudwatch_to_call_check" {
#   for_each      = aws_lambda_function.lambda_functions
#   statement_id  = "AllowExecutionFromCloudWatch"
#   action        = "lambda:InvokeFunction"
#   function_name = each.value.function_name
#   principal     = "events.amazonaws.com"
#   source_arn    = aws_cloudwatch_event_rule.cron_job_lambda.arn
# }
