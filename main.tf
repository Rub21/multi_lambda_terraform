
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
data "archive_file" "zip_lambda_folders" {
  for_each    = fileset(path.module, "scripts/*/index.py")
  type        = "zip"
  source_dir  = dirname(each.key)
  output_path = "${dirname(each.key)}.zip"
}

resource "aws_lambda_function" "lambda_functions" {
  for_each      = fileset(path.module, "scripts/*.zip")
  filename      = "${path.module}/${each.key}"
  function_name = "multi_${replace(basename(each.key), ".zip", "")}"
  role          = aws_iam_role.lambda_role.arn
  handler       = "index.lambda_handler"
  runtime       = "python3.8"
  depends_on    = [aws_iam_role_policy_attachment.attach_iam_policy_to_iam_role]
}
