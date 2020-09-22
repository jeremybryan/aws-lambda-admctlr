resource "aws_apigatewayv2_api" "vhook" {
  name        = "ValidatingWebHook"
  description = "Terraform Serverless ValidatingWebHook Example"
  protocol_type = "HTTP" 
}
 
resource "aws_apigatewayv2_route" "vhook" {
  api_id    = aws_apigatewayv2_api.vhook.id
  route_key = "$default"
}

resource "aws_apigatewayv2_route" "validate" {
  api_id    = aws_apigatewayv2_api.vhook.id
  route_key = "POST /validate"
  authorization_type = "NONE"
  target = "integrations/${aws_apigatewayv2_integration.validate_integration.id}"
}

resource "aws_apigatewayv2_integration" "validate_integration" {
  api_id           = aws_apigatewayv2_api.vhook.id
  integration_type = "AWS_PROXY"
  integration_uri  = aws_lambda_function.vhook.invoke_arn
}

resource "aws_apigatewayv2_stage" "prod_stage" {
  api_id      = aws_apigatewayv2_api.vhook.id
  name        = "prod"
  auto_deploy = true
  route_settings {
    route_key                = aws_apigatewayv2_route.validate.route_key
    logging_level            = "INFO"
    detailed_metrics_enabled = true
  }
}

