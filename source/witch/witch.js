const aws = require("aws-sdk");
const fs = require("fs");
const path = require("path");
const mime = require("mime-types");

const s3 = new aws.S3();

const SUCCESS = "SUCCESS";
const FAILED = "FAILED";

const BUCKET = process.env.BUCKET;

exports.staticHandler = function(event, context) {
    if (event.RequestType !== "Create" && event.RequestType !== "Update") {
        return respond(event, context, SUCCESS, {});
    }

    Promise.all(walkSync("./").map(file => {
        var fileType = mime.lookup(file) || "application/octet-stream";

        console.log(`${file} -> ${fileType}`);

        return s3.upload({
            Body: fs.createReadStream(file),
            Bucket: BUCKET,
            ContentType: fileType,
            Key: file,
            ACL: "private",
        }).promise();
    })).then((msg) => {
        respond(event, context, SUCCESS, {});
    }).catch(err => {
        respond(event, context, FAILED, {Message: err});
    });
};

// List all files in a directory in Node.js recursively in a synchronous fashion
function walkSync(dir, filelist) {
	var files = fs.readdirSync(dir);
	filelist = filelist || [];

	files.forEach(function(file) {
		if (fs.statSync(path.join(dir, file)).isDirectory()) {
			filelist = walkSync(path.join(dir, file), filelist);
		} else {
			filelist.push(path.join(dir, file));
		}
	});

	return filelist;
};

function respond(event, context, responseStatus, responseData, physicalResourceId, noEcho) {
    var responseBody = JSON.stringify({
        Status: responseStatus,
        Reason: "See the details in CloudWatch Log Stream: " + context.logStreamName,
        PhysicalResourceId: physicalResourceId || context.logStreamName,
        StackId: event.StackId,
        RequestId: event.RequestId,
        LogicalResourceId: event.LogicalResourceId,
        NoEcho: noEcho || false,
        Data: responseData
    });
 
    console.log("Response body:\n", responseBody);
 
    var https = require("https");
    var url = require("url");
 
    var parsedUrl = url.parse(event.ResponseURL);
    var options = {
        hostname: parsedUrl.hostname,
        port: 443,
        path: parsedUrl.path,
        method: "PUT",
        headers: {
            "content-type": "",
            "content-length": responseBody.length
        }
    };
 
    var request = https.request(options, function(response) {
        console.log("Status code: " + response.statusCode);
        console.log("Status message: " + response.statusMessage);
        context.done();
    });
 
    request.on("error", function(error) {
        console.log("send(..) failed executing https.request(..): " + error);
        context.done();
    });
 
    request.write(responseBody);
    request.end();
}
