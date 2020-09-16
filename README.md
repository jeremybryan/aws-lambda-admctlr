### AWS Lambda Admission Controller Example

#### Key Components 

* NodeJS based (or any language) based Lambda to serve as the admission controller webhook
* API Gateway to serve as a the HTTP based end point for Kubernetes to talk to
* AdmissionController (ValidatingWebhookConfiguration) 

#### Deployment Approach

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
    aws lambda create-function --function-name my-function \
    --zip-file fileb://function.zip --handler index.handler --runtime nodejs12.x \
    --role arn:aws:iam::123456789012:role/adminctlr
    ```
    Then the function can be tested:
    ```
    aws lambda invoke --function-name adminctlr out --log-type Tail  
    ```
##### API Gateway

* Create the API Gateway
  
    The API Gateway API will also need to had permission to call the lambda
    ```
    aws lambda add-permission \
      --statement-id 88bf023d-8d5b-5a4a-85ca-c03e0c4718b1 \
      --action lambda:InvokeFunction \
      --function-name "arn:aws-us-gov:lambda:us-gov-west-1:137782974070:function:admission-controller" \
      --principal apigateway.amazonaws.com \
      --source-arn "arn:aws-us-gov:execute-api:us-gov-west-1:137782974070:np2fkaua6h/*/*/validate"
    ```
  
Testing and Verifying
-
