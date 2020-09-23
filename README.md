### AWS Lambda Admission Controller Example

There are two approaches here, the shell scripted approach and the Terraform provisioned approach.
The Terraform approach exists in the `terraform` branch.

#### Key Components 

* NodeJS based (or any language) based Lambda to serve as the admission controller webhook
* API Gateway to serve as a the HTTP based end point for Kubernetes to talk to
* AdmissionController (ValidatingWebhookConfiguration) 

#### Deployment Approach
  Below are a set of instructions for provisioning the lambda, apigateway and all policies/roles. 
  
  If you have multiples AWS Cli profiles be sure to add the --profile <profile name> argument 
  
##### Lambda
* Create the trust policy for the lambda
     
     ```
     aws iam create-role --role-name adminctlr --assume-role-policy-document file://trust-policy.json
    ```

* Then add policies to it

    The `AWSLambdaBasicExecutionRole` The AWSLambdaBasicExecutionRole policy has the permissions that the function needs to write logs to CloudWatch Logs
    
    ```
    aws iam attach-role-policy --role-name adminctlr --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole
    ```
  
* Create the lambda
    The function contents needs to be zipped up (function.zip below). The --handler option specifies the name of the handler
    in the zip file.
    
    Note: The role arn below needs to be replaced with the ARN for the role created above.
    ```
    aws lambda create-function --function-name adminctlr \
    --zip-file fileb://function.zip --handler index.handler --runtime nodejs12.x \
    --role arn:aws:iam::123456789012:role/adminctlr
    ```
    The shell script `createFunction.sh` can be used for the above. A specific profile name can be passed as the first 
    argument to the script
    cli profile name and the second the ARN for the `--role` parameter.
    
    Then the function can be tested:
    ```
    aws lambda invoke --function-name adminctlr out --log-type Tail  
    ```
##### API Gateway

* Create the API Gateway

    The arn below needs to be the arn of the lambda function 
    ```
    aws apigatewayv2 create-api --name validate-api --protocol-type HTTP --target arn:aws:lambda:us-east-2:123456789012:function:function-name
  
    ```
  
    The API Gateway API will also need to had permission to call the lambda
    ```
    aws lambda add-permission \
      --statement-id <some unique identifier> \
      --action lambda:InvokeFunction \
      --function-name "arn:aws-us-gov:lambda:us-gov-west-1:137782974070:function:admission-controller" \
      --principal apigateway.amazonaws.com \
      --source-arn "arn:aws-us-gov:execute-api:us-gov-west-1:137782974070:np2fkaua6h/*/*/validate"
    ```
* Create the Route and Add Permission to the Lambda

    Next we need to create the route we want on the gateway and then create a connection to the lambda function
    In the below the gateway-api-id is the id of the gateway api and the integration id is the id of the configured
    integration on the gateway.
       
    Both the gateway-api-id and the integration-id can be obtained from the console or via the cli.
          
    ```
     aws apigatewayv2 create-route --api-id <gateway-api-id> --route-key 'POST /validate' \
             --target integrations/<gateway-integration-id>"
    ```

##### Deploy the Webhook
   
   To exercise the lambda we need to deploy the controller to the k8s instance. 
   Before doing this we need to adjust the controller with the correct api id and the 
   correct region.
   
   ``` 
    kubectl apply -f controller.yaml  
  ```
     
The script `provision.sh` provides a simplistic automation of the above steps. 
```
./provision.sh <aws cli profile> <empty or clean>
```
The first argument is the aws cli profile you want to use (default or other named profile)
The second argument is empty or `clean` in the case when you want to clean up what's been provisioned

Testing and Verifying
-
```
curl --header "Content-Type: application/json" --request POST --data @sample.json https://<API_ID>.execute-api.us-gov-west-1.amazonaws.com/validate
```
#### ValidationWebhook
`controller.yaml` contains the configuration required to deploy a validation webhook to kubernetes. Line 18 is the line
that would need to be updated prior to provisioning to Kubernetes, this line would need to be updated with the `output` 
line from the terraform provisioing process it will look like:
 
 `validating_webhook_url = https://XXXXXXXXXX.execute-api.us-gov-west-1.amazonaws.com/prod`


The function defined index.js is checking for environment variables configured in a container deployment yaml. If the 
function finds an env variable, the deployment is failed. This could be tested in the following way:

Successful Deployment
 Run `kubectl run nginx --image=nginx` and observe the deployment completes successfully.

Denied Deployment 
 Run `kubectl run nginx-with-env --image=nginx --env="SOMEVALUE=fail"` and observe the deployment is denied.