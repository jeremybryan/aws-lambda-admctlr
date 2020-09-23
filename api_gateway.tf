resource "aws_apigatewayv2_api" "vhook" {
  name        = "validatingWebHook"
  description = "Terraform Serverless ValidatingWebHook"
  protocol_type = "HTTP" 
}
 
resource "aws_apigatewayv2_route" "vhook" {
  api_id    = aws_apigatewayv2_api.vhook.id
  route_key = "$default"
  target = "integrations/${aws_apigatewayv2_integration.validate_integration.id}"
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
    throttling_rate_limit    = 20
    throttling_burst_limit   = 20
    detailed_metrics_enabled = true
  }
}

output validating_webhook_url {
   value = aws_apigatewayv2_stage.prod_stage.invoke_url
}

resource "time_sleep" "wait_5_seconds" {
  depends_on = [aws_apigatewayv2_stage.prod_stage]

  create_duration = "5s"
}

resource "null_resource" "webhook-test" {
  depends_on = [time_sleep.wait_5_seconds]
  provisioner "local-exec" {
      command = <<EOT
        curl -s -X POST "${aws_apigatewayv2_stage.prod_stage.invoke_url}/validate" \
             -H 'Content-Type: application/json' \
             -d @test/sample.json
EOT
  }
}
