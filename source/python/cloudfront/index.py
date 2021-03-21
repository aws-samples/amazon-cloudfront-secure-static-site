import logging
import uuid

import boto3
from crhelper import CfnResource
from tenacity import retry, retry_if_result, wait_fixed

logger = logging.getLogger(__name__)
helper = CfnResource(json_logging=True, log_level='DEBUG',
                     boto_level='CRITICAL', sleep_on_delete=120)

try:
    cloudfront = boto3.client("cloudfront")
except Exception as e:
    logger.error(e, exc_info=True)
    helper.init_failure(e)


def log_exception(e):
    print(getattr(e, 'message', repr(e)))
    logger.error(e)


@helper.create
def create(event, context):
    logger.info("got CREATE")
    apex_from_config = event["ResourceProperties"]["Apex"]
    subdomain = event["ResourceProperties"]["Subdomain"]
    domain_name = event["ResourceProperties"]["Domain"]
    stack_name = event["ResourceProperties"]["StackName"]
    bucket_root = event["ResourceProperties"]["SiteBucketRootName"]
    bucket_logs = event["ResourceProperties"]["LogsBucket"]
    bucket_arn = event["ResourceProperties"]["SiteBucketArn"]
    lambda_arnWver = event["ResourceProperties"]["SecureEdgeFunctionArn"]
    amplify_hosting = event["ResourceProperties"]["AmplifyHosting"]
    repo_branch = event["ResourceProperties"]["Branch"]
    with_domain_name = event["ResourceProperties"]["WithDomainName"]

    amplify_hosting_url = repo_branch+'.'+amplify_hosting


    certificate_arn = event["ResourceProperties"]["CertArn"]
    create_apex_config = True if (apex_from_config == "yes") else False
    create_domain_name = True if (with_domain_name == "true") else False
    tags = {
        "Items": [
            {
                "Key": "Name",
                "Value": f"{stack_name}-Distribution"
            }
        ]
    }
    config = {
        "CallerReference": f"{uuid.uuid4()}",
#        "Aliases": {
#            "Quantity": 1,
#            "Items": [f"{domain_name}" if create_apex_config else f"{subdomain}.{domain_name}"]
#        },
        "DefaultCacheBehavior": {
            "TrustedSigners": {
                "Enabled": False,
                "Quantity": 0
            },
            "Compress": True,
            "DefaultTTL": 86400,
            "ForwardedValues": {
                "QueryString": True,
                "Cookies": {"Forward": "all"}
            },
            "MaxTTL": 31536000,
            "MinTTL": 600,
            "DefaultTTL": 86400,

            "TargetOriginId": "myCustomOrigin",
            "ViewerProtocolPolicy": "redirect-to-https",
            "LambdaFunctionAssociations": {
                "Quantity": 1,
                "Items": [
                    {
                        "EventType": "origin-response",
                        "LambdaFunctionARN": lambda_arnWver
                    }
                ]
            },
        },
        "CustomErrorResponses": {
            "Quantity": 2,
            "Items": [
                {
                    "ErrorCachingMinTTL": 60,
                    "ErrorCode": 404,
                    "ResponseCode": "404",
                    "ResponsePagePath": "/404.html"
                },
                {
                    "ErrorCachingMinTTL": 60,
                    "ErrorCode": 403,
                    "ResponseCode": "403",
                    "ResponsePagePath": "/403.html"
                }]
        },
        "Enabled": True,
        "HttpVersion": "http2",
        "DefaultRootObject": "index.html",
        "IsIPV6Enabled": True,
        "Comment": f"{subdomain}.{domain_name}" if create_domain_name else "Distribution for static website" ,
        "Logging": {
            "Enabled": True,
            "Bucket":  bucket_logs,
            "IncludeCookies": False,
            "Prefix": "cdn/"
        },
        "Origins": {
            "Quantity": 1,
            "Items": [
                {
                    "DomainName":  amplify_hosting_url,
                    "Id": "myCustomOrigin",
                    "CustomOriginConfig" : {
                             "HTTPPort" : 80,
                             "HTTPSPort" : 443,
                             "OriginProtocolPolicy" : "match-viewer"
                         }

                }
            ]
        },
        "PriceClass": "PriceClass_All"
    #    "ViewerCertificate": {
#            "ACMCertificateArn":  certificate_arn,
    #        "MinimumProtocolVersion": "TLSv1.1_2016",
    #        "SSLSupportMethod": "sni-only"
    #    }
    }

    if create_domain_name:
     config["Aliases"] = {
                "Quantity": 1,
                "Items": [f"{domain_name}" if create_apex_config else f"{subdomain}.{domain_name}"]
     }
     config["ViewerCertificate"] = {
                "ACMCertificateArn":  certificate_arn,
                "MinimumProtocolVersion": "TLSv1.1_2016",
                "SSLSupportMethod": "sni-only"
     }


    print(config)
    logger.info(config)

    response = cloudfront.create_distribution_with_tags(
        DistributionConfigWithTags={
            "DistributionConfig": config,
            "Tags": tags
        }
    )
    helper.Data.update({"DomainName": response["Distribution"]["DomainName"]})
    helper.Data.update({"DistroId": response["Distribution"]["Id"]})
    helper.Data.update({"Status": response["Distribution"]["Status"]})
    helper.Data.update({"ETag": response["ETag"]})
    return response["Distribution"]["Id"]


@helper.update
def update(event, context):
    """not implemented"""
    logger.info("got UPDATE")
    pass


@helper.delete
def delete(event, context):
    response = cloudfront.get_distribution(
        Id=event["PhysicalResourceId"])  # get details
    etag = response["ETag"]
    config = response["Distribution"]["DistributionConfig"]
    distroid = response["Distribution"]["Id"]
    config.update({"Enabled": False})  # set to disable
    response = cloudfront.update_distribution(
        DistributionConfig=config, Id=distroid, IfMatch=etag)  # do disable
    distroid = response["Distribution"]["Id"]
    disable_distribution(distroid)
    response = cloudfront.get_distribution(Id=distroid)
    etag = response["ETag"]
    distroid = response["Distribution"]["Id"]
    cloudfront.delete_distribution(Id=distroid, IfMatch=etag)


def is_disabled(result):
    return True if result.lower() == "inprogress" else False


@retry(retry=retry_if_result(is_disabled), wait=wait_fixed(20))
def disable_distribution(distroid):
    return cloudfront.get_distribution(Id=distroid)["Distribution"]["Status"]


def handler(event, context):
    global logger
    helper(event, context)
