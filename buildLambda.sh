#!/bin/bash

echo "Building lambda package"
zip function.zip index.js

echo "Initializing Terraforn build out"
terraform apply --auto-approve

echo "Deleting lambda function bundle"
rm function.zip
