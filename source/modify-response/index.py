import boto3
import uuid
import zipfile
from crhelper import CfnResource
from decorators import with_logging


helper = CfnResource(json_logging=False, log_level='DEBUG',
                     boto_level='CRITICAL')

lambda_code = """
def handler(event, context):
    response = event['Records'][0]['cf']['response']
    h = response['headers']
    return response
"""

client = boto3.client("lambda", region_name='us-east-1')


def zip_lambda_code():
    lambda_code_path = "/tmp/lambda_code.zip"
    with zipfile.ZipFile(lambda_code_path, mode="w", compression=zipfile.ZIP_DEFLATED) as zf:
        info = zipfile.ZipInfo("append_headers.py")
        info.external_attr = 0o777 << 16
        zf.writestr(info, lambda_code)
        zf.close()
    return lambda_code_path


@with_logging
@helper.create
@helper.update
def create(event, context):
    lambda_code_path = zip_lambda_code()
    props = event.get('ResourceProperties', None)
    lambda_role_arn = props.get("RoleArn")
    resource_prefix = props.get("ResourcePrefix")
    lambda_function_name = "{}-{}".format(resource_prefix, uuid.uuid4())
    with open(lambda_code_path, 'rb') as zf:
        response = client.create_function(
            FunctionName=lambda_function_name,
            Runtime='python3.7',
            Role=lambda_role_arn,
            Handler='append_headers.handler',
            Code={'ZipFile': zf.read()},
            Description='Lambda@Edge for secure headers',
            Timeout=5,
            Publish=True
        )

        function_arn = response['FunctionArn']
        with_version = "{}:{}".format(function_arn, response['Version'])
        helper.Data.update({"FunctionArnWithVersion": with_version})

        return function_arn


@with_logging
@helper.delete
def delete(event, context):
    return None


def handler(event, context):
    helper(event, context)

