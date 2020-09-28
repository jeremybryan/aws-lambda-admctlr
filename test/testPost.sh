echo "Using API_ID: $1"
curl --header "Content-Type: application/json" --request POST --data @sample.json "$1"/validate
