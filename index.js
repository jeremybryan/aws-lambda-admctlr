exports.handler = async function(event, context) {
  console.log('Handling request');
  console.log('## ENVIRONMENT VARIABLES: ' + serialize(process.env));
  console.log('## CONTEXT: ' + serialize(context));
  console.log('## EVENT: ' + serialize(event));
  
  var admissionRequest = JSON.parse(event.body);
  console.log('## AdminRequest: ' + admissionRequest);

  // Get a reference to the pod spec
  var object = admissionRequest.request.object;
  console.log('## Object: ' + object);

  console.log(`validating the ${object.metadata.name} pod`);

  var admissionResponse = {
    allowed: false
  };

  var found = false;
  for (var container of object.spec.containers) {
    if ("env" in container) {
      console.log(`${container.name} is using env vars`);

      admissionResponse.status = {
        status: 'Failure',
        message: `${container.name} is using env vars`,
        reason: `${container.name} is using env vars`,
        code: 402
      };

      found = true;
    }
  }

  if (!found) {
    admissionResponse.allowed = true;
  }

  var admissionReview = {
    response: admissionResponse
  };

  var response = {
        "statusCode": 200,
        "headers": {
            "Content-Type": "application/json"
        },
        "isBase64Encoded": false,
        "body": JSON.stringify(admissionReview)
    }

  return response;
}

var serialize = function(object) {
  return JSON.stringify(object, null, 2)
}
