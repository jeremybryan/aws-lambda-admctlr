### AWS Lambda Admission Controller Example

#### Key Components 

* NodeJS based (or any language) based Lambda to serve as the admission controller webhook
* API Gateway to serve as a the HTTP based end point for Kubernetes to talk to
* AdmissionController (ValidatingWebhookConfiguration) 

#### Deployment Approach
  This branch uses terraform to provision all components including:
  * Create the S3 bucket
  * Move the zipped function to the S3 bucket
  * Creating the role required by the lambda
  * Associating the policy required by the role for the lambda
  * Create the lambda based upon the function in the S3 bucket
  * Create the api gateway function including the integration, stage and route
  * Run a test against the provisioned endpoint
  
  The script `buildLambda.sh` will handle the entire creation activity (to include zipping the function up prior to
  pushing to S3.)
  
  Simply run `./buildLambda.sh` to provision.
  
  To destroy, run `terraform destroy --auto-approve`
  
#### Testing and Verifying
The terraform scripts has been instrumented with a validate test to ensure the enpoint is working properly. It performs 
the following:

```
curl --header "Content-Type: application/json" --request POST --data @sample.json https://<API_ID>.execute-api.us-gov-west-1.amazonaws.com/validate
```

You will know this is working if you see `null_resource.webhook-test (local-exec): {"response":{"allowed":true}}` at the
end of the call to `./buildLambda.sh`


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
