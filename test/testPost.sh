echo "Using API_ID: $1"
curl --header "Content-Type: application/json" --request POST --data @sample.json https://"$1".execute-api.us-gov-west-1.amazonaws.com/prod/validate
