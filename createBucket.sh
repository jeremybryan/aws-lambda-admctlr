aws --profile tapestry s3api create-bucket --bucket terraform-validatingwebhook --create-bucket-configuration LocationConstraint=us-gov-west-1

zip function.zip index.js
aws --profile tapestry s3 cp function.zip s3://terraform-validatingwebhook/v1.0/function.zip

