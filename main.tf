
provider "aws" {
  region = "eu-central-1"
}

resource "aws_iam_policy" "lambda_policy" {
  name        = "lambda_policy"
  description = "AWS IAM Policy for managing aws lambda role"
  policy      = file("${path.module}/iam-roles/lambda-policy.json")
}

resource "aws_iam_role" "lambda_role" {
  name               = "lambda_role"
  assume_role_policy = file("${path.module}/iam-roles/lambda-assume-policy.json")
}

resource "aws_iam_role_policy_attachment" "attach_iam_policy_to_iam_role" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_policy.arn
}

############################################################
###### Create single lambda function
############################################################
data "archive_file" "zip_a_lambda_folder" {
  type        = "zip"
  source_dir  = "${path.module}/scripts/hello1/"
  output_path = "${path.module}/scripts/hello1.zip"
}
resource "aws_lambda_function" "terraform_lambda_func" {
  filename      = "${path.module}/scripts/hello1.zip"
  function_name = "a_lambda_function"
  role          = aws_iam_role.lambda_role.arn
  handler       = "index.lambda_handler"
  runtime       = "python3.8"
  depends_on    = [aws_iam_role_policy_attachment.attach_iam_policy_to_iam_role]
}

############################################################
###### Create multiple lambda functions
############################################################

locals {
  lambda_configs = [for f in fileset(path.module, "scripts/*/index.py") :
    {
      lambda_folder_index  = f
      lambda_folder        = dirname(f)
      lambda_function_name = "multi_${replace(basename(dirname(f)), ".py", "")}"
      lambda_zip_folder    = "${dirname(f)}.zip"
    }
  ]
}

data "archive_file" "zip_lambda_folders" {
  for_each    = { for cj in local.lambda_configs : cj.lambda_folder_index => cj }
  type        = "zip"
  source_dir  = each.value.lambda_folder
  output_path = each.value.lambda_zip_folder
}

resource "aws_lambda_function" "lambda_functions" {
  for_each      = { for cj in local.lambda_configs : cj.lambda_folder_index => cj }
  filename      = each.value.lambda_zip_folder
  function_name = each.value.lambda_function_name
  role          = aws_iam_role.lambda_role.arn
  handler       = "index.lambda_handler"
  runtime       = "python3.8"
  depends_on    = [aws_iam_role_policy_attachment.attach_iam_policy_to_iam_role]
}

############################################################
###### Create multiple lambda functions
############################################################

resource "aws_cloudwatch_event_rule" "every_one_minute" {
  name                = "every-one-minute"
  description         = "Fires every one minutes"
  schedule_expression = "rate(1 minute)"
}

resource "aws_cloudwatch_event_target" "check_foo_every_one_minute" {
  for_each  = aws_lambda_function.lambda_functions
  rule      = aws_cloudwatch_event_rule.every_one_minute.name
  target_id = each.value.function_name
  arn       = each.value.arn
}

resource "aws_lambda_permission" "allow_cloudwatch_to_call_check" {
  for_each      = aws_lambda_function.lambda_functions
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = each.value.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.every_one_minute.arn
}