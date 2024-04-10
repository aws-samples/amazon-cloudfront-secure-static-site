const { S3Client, PutObjectCommand } = require('@aws-sdk/client-s3');
const fs = require('node:fs');
const path = require('node:path');
const mime = require('mime-types');
const https = require('node:https');
const url = require('node:url');

const s3Client = new S3Client();

const SUCCESS = 'SUCCESS';
const FAILED = 'FAILED';

const { BUCKET } = process.env;

exports.staticHandler = (event, context) => {
  if (event.RequestType !== 'Create' && event.RequestType !== 'Update') {
    return respond(event, context, SUCCESS, {});
  }

  Promise.all(
    walkSync('./').map((file) => {
      const fileType = mime.lookup(file) || 'application/octet-stream';

      console.log(`${file} -> ${fileType}`);

      return s3Client.send(
        new PutObjectCommand({
          Body: fs.createReadStream(file),
          Bucket: BUCKET,
          ContentType: fileType,
          Key: file,
          ACL: 'private',
        })
      );
    })
  )
    .then((msg) => {
      respond(event, context, SUCCESS, {});
    })
    .catch((err) => {
      respond(event, context, FAILED, { Message: err });
    });
};

// List all files in a directory in Node.js recursively in a synchronous fashion
function walkSync(dir, filelist = []) {
  const files = fs.readdirSync(dir);

  files.forEach(function (file) {
    if (fs.statSync(path.join(dir, file)).isDirectory()) {
      filelist = walkSync(path.join(dir, file), filelist);
    } else {
      filelist.push(path.join(dir, file));
    }
  });

  return filelist;
}

function respond(
  event,
  context,
  responseStatus,
  responseData,
  physicalResourceId,
  noEcho
) {
  const responseBody = JSON.stringify({
    Status: responseStatus,
    Reason: `See the details in CloudWatch Log Stream: ${context.logStreamName}`,
    PhysicalResourceId: physicalResourceId || context.logStreamName,
    StackId: event.StackId,
    RequestId: event.RequestId,
    LogicalResourceId: event.LogicalResourceId,
    NoEcho: noEcho || false,
    Data: responseData,
  });

  console.log('Response body:\n', responseBody);

  const { pathname, hostname, search } = new url.URL(event.ResponseURL);
  const options = {
    hostname,
    port: 443,
    path: pathname + search,
    method: 'PUT',
    headers: {
      'content-type': '',
      'content-length': responseBody.length,
    },
  };

  const request = https.request(options, (response) => {
    console.log(`Status code: ${response.statusCode}`);
    console.log(`Status message: ${response.statusMessage}`);
    context.done();
  });

  request.on('error', (error) => {
    console.log(`send(..) failed executing https.request(..): ${error}`);
    context.done();
  });

  request.write(responseBody);
  request.end();
}
