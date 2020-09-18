#!/usr/bin/env bash

#
#  Arg 1 is profile
#  Arg 2 is empty or "clean" if you want to clean things up
#
function get_api_id() {
  API_ID=$(aws --profile "$PROFILE" apigatewayv2 get-apis | jq -r '.Items[] | select(.Name=="validate-api") | .ApiId')
}

function define_partition() {
  PARTITION=$(aws --profile "$PROFILE" iam get-user | jq -r '.User .Arn' | cut -d':' -f2)
}

function get_function_arn() {
  FUNCTARN=$(aws lambda list-functions --profile $PROFILE | jq -r '.Functions[] | select(.FunctionName=="adminctlr") | .FunctionArn')
}

function get_role_arn() {
  ROLEARN=$(aws iam list-roles --profile $PROFILE | jq -r '.Roles[] | select(.RoleName=="adminctlr") | .Arn')
}

function get_int_id() {
  INT_ID=$(aws --profile "$PROFILE" apigatewayv2 get-integrations --api-id "$API_ID" | jq -r '.Items[] | select (.IntegrationMethod=="POST") | .IntegrationId')
}

function build_execute_api_endpoint() {
  EXECUTE_API="arn:$PARTITION:execute-api:$REGION:$ACT_ID:$API_ID/*/*/validate"
}

function bundle_the_function() {
  zip function.zip index.js
}

function define_profile() {
  if [[ "$1" != "" ]]; then
    PROFILE="$1"
  else
    PROFILE="default"
  fi
  echo "Using profile $PROFILE"
}

define_profile $1
define_partition

if [[ "$2" != "clean" ]]; then

  echo "Creating role and adding execution policy"
  aws --profile "$PROFILE" iam create-role --role-name adminctlr --assume-role-policy-document file://trust-policy.json

  # Grab the role arn
  get_role_arn
  echo "ROLEARN=$ROLEARN"
  sleep 5

  aws --profile "$PROFILE" iam attach-role-policy --role-name adminctlr --policy-arn arn:"$PARTITION":iam::aws:policy/service-role/AWSLambdaBasicExecutionRole

  sleep 5
  echo "Creating the Lambda function"
  bundle_the_function
  aws --profile "$PROFILE" lambda create-function --function-name adminctlr --zip-file fileb://function.zip \
  --handler index.handler --runtime nodejs12.x --role "$ROLEARN"

  # Grab a few values
  get_function_arn
  # We need these to construct the execute-api arn when linking the integration to the lambda
  REGION=$(echo "$FUNCTARN" | cut -d':' -f4)
  ACT_ID=$(echo "$FUNCTARN" | cut -d':' -f5)

  sleep 5

  #Create the api, this also creates an integration which we assign later
  echo "Create Gateway API"
  aws --profile "$PROFILE" apigatewayv2 create-api --name validate-api --protocol-type HTTP --target "$FUNCTARN"

  get_api_id
  echo "Using api_id $API_ID"

  #Create and associated the integration between the API and the Lambda function
  #echo "Creating integration"
  #aws apigatewayv2 create-integration --profile $PROFILE --api-id "$API_ID" --integration-type AWS_PROXY --integration-uri "$FUNCTARN" --payload-format-version 2.0
  get_int_id
  echo "Creating route with $API_ID and $INT_ID"
  aws --profile "$PROFILE" apigatewayv2 create-route --api-id "$API_ID" --route-key 'POST /validate' --target integrations/"$INT_ID"

  echo "Adding Permission to Lambda to allow API to invoke it"
  # Needs to align to API Gateway Execute-Api ARN
  # https://docs.aws.amazon.com/apigateway/latest/developerguide/arn-format-reference.html
  build_execute_api_endpoint
  aws --profile "$PROFILE" lambda add-permission --statement-id adminctlr-id --action lambda:InvokeFunction \
  --function-name "$FUNCTARN" --principal apigateway.amazonaws.com --source-arn "$EXECUTE_API"

  echo "EndPointApi to call"
  aws --profile tapestry apigatewayv2 get-api --api-id "$API_ID" | jq -r .ApiEndpoint

fi

if [[ "$2" == "clean" ]]; then
  #Clean it all up
  get_api_id
  echo "Deleting API Gateway"
  aws --profile "$PROFILE" apigatewayv2 delete-api --api-id "$API_ID"

  echo "Deleting Lambda"
  aws --profile "$PROFILE" lambda delete-function --function-name adminctlr

  echo "Detaching policy from role"
  aws --profile "$PROFILE" iam detach-role-policy --role-name adminctlr --policy-arn arn:"$PARTITION":iam::aws:policy/service-role/AWSLambdaBasicExecutionRole

  echo "Deleting role"
  aws --profile "$PROFILE" iam delete-role --role-name adminctlr
fi
