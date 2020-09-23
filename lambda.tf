terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}

provider "aws" {
   profile = "tapestry"
   region = "us-gov-west-1"
}

resource "aws_s3_bucket" "lambda_function_bucket" {
  bucket = "validatingwebhook-lambda-package"
  acl    = "private"
}

resource "aws_s3_bucket_object" "package" {
  bucket = aws_s3_bucket.lambda_function_bucket.id
  key    = "v1.0/function.zip"
  source = "function.zip"

}

resource "aws_lambda_function" "vhook" {
   function_name = "validatingWebHook"

   # The bucket name as created earlier with "aws s3api create-bucket"
   s3_bucket = aws_s3_bucket.lambda_function_bucket.id
   s3_key    = aws_s3_bucket_object.package.key

   # "main" is the filename within the zip file (main.js) and "handler"
   # is the name of the property under which the handler function was
   # exported in that file.
   handler = "index.handler"
   runtime = "nodejs12.x"

   role = aws_iam_role.lambda_exec.arn
}

 # IAM role which dictates what other AWS services the Lambda function
 # may access.
resource "aws_iam_role" "lambda_exec" {
   name = "validation-webhook-lambda"

   assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF

}

resource "aws_iam_role_policy_attachment" "lambda-exec-role"{
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws-us-gov:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_lambda_permission" "apigw" {
   statement_id  = "AllowAPIGatewayInvoke"
   action        = "lambda:InvokeFunction"
   function_name = aws_lambda_function.vhook.function_name
   principal     = "apigateway.amazonaws.com"

   # The "/*/*" portion grants access from any method on any resource
   # within the API Gateway REST API.
   source_arn = "${aws_apigatewayv2_api.vhook.execution_arn}/*/*/validate"
}


