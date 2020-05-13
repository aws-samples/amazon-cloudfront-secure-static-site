Amazon CloudFront Secure Static Site
=====================================
 
Creating a Secure Static Site for your registered domain - hosted on Amazon S3 and Distributed by Amazon CloudFront.



## Overview
===========

### Prerequisites
The Solution assumes that you have registered a domain, such as example.com, and have pointed it to a Route53 Hosted Zone in the account in which you will deploy this Solution.  See [here](https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/dns-configuring.html) for details of how to do this.

### Solution overview
=====================


This solution creates a simple static website, hosted in an [Amazon S3](https://aws.amazon.com/s3/faqs/) bucket and distributed with [Amazon CloudFront](https://aws.amazon.com/cloudfront/faqs/). A Lambda@Edge function is triggered on an [origin response](https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/lambda-cloudfront-trigger-events.html) event.


Certain common attacks can be mitigated with the use of Security Headers.  These headers are typically added by an application configuration when a requested object is served.  In this case Security Headers are appended to served objects using Lambda@Edge as per [this blogpost](https://aws.amazon.com/blogs/networking-and-content-delivery/adding-http-security-headers-using-lambdaedge-and-amazon-cloudfront/)

### S3 configuration
Deploying the Solution creates an S3 bucket which hosts assets that comprise a static website.  The website will only be accessible via the configured CloudFront Distribution.  

### ACM configuration
The Solution will create an SSL Certificate for your website which will use DNS to validate ownership of the domain.  This SSL Certificate will be attached to the site's CloudFront Distribution.

### CloudFront configuration
CloudFront will be configured to distribute traffic for your domain.  The Origin  will be the S3 Bucket which contains your website assets.  Access to the content on the S3 content will be restricted using [Origin Access Identity](https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/private-content-restricting-access-to-s3.html).

The CloudFront distribution is additionally configured with a [Lambda@Edge Function](https://aws.amazon.com/lambda/edge/) which implements Header based security on HTTP Request.

### Security Header configuration
============================

Security headers are a group of headers in the HTTP response that specify whether particular security precautions are enabled or disabled in a browser. `Content-Security-Policy` is a header that provides an added layer of security.  It helps to detect and mitigate certain types of attacks, including Cross Site Scripting (XSS) and data injection attacks. The following is a list of headers that are supported in this Solution.

[Strict Transport Security](https://infosec.mozilla.org/guidelines/web_security#http-strict-transport-security)

[Content-Security-Policy](https://infosec.mozilla.org/guidelines/web_security#content-security-policy)

[X-Content-Type-Options](https://infosec.mozilla.org/guidelines/web_security#x-content-type-options)

[X-Frame-Options](https://infosec.mozilla.org/guidelines/web_security#x-frame-options)

[X-XSS-Protection](https://infosec.mozilla.org/guidelines/web_security#x-xss-protection)

[Referrer-Policy](https://infosec.mozilla.org/guidelines/web_security#referrer-policy)

Additional details on each of these security headers can be found in [Mozilla’s Web Security Guide](https://infosec.mozilla.org/guidelines/web_security).

### Lambda@Edge configuration
=======================

Lambda@Edge provides the ability to execute a [node.js](https://nodejs.org/en/) function at an Amazon CloudFront location. This enables the processing of HTTP requests close to the customer. Lambda@Edge can also be used when it is not possible or convenient to perform processing at the origin - i.e. where content is hosted.

The following diagram illustrates the sequence of events for triggering our Lambda@Edge function:

![Architecture](./docs/images/architecture.png)

Here is how the process works:

1. The Viewer requests the website www.example.com.
2. If the requested object is cached, CloudFront will return the object from it's cache to the Viewer.
3. If the object is not in cache CloudFront requests the object from the Origin, which in this case is an S3 bucket.
4. S3 returns the object, which in turn causes CloudFront to trigger the origin response event.
5. The Security-Headers Lambda function triggers, and the resulting output is cached and served by CloudFront.



## Deployment

The solution is deployed as an
[AWS CloudFormation](https://aws.amazon.com/cloudformation) template.

Your access to the AWS account must have IAM permissions to launch AWS
CloudFormation templates that create IAM roles and to create the solution
resources.

> **Note** You are responsible for the cost of the AWS services used while
> running this solution. For full details, see the pricing pages for each AWS
> service you will be using in this sample. Prices are subject to change.

1. Deploy the latest CloudFormation template using the AWS Console by choosing the "*Launch Template*" button below for your preferred AWS region. If you wish to [deploy using the AWS CLI] instead, you can refer to the "*Template Link*" to download the template files.



2. If prompted, login using your AWS account credentials.
3. You should see a screen titled "*Create Stack*" at the "*Specify template*"
   step. The fields specifying the CloudFormation template are pre-populated.
   Choose the *Next* button at the bottom of the page.
4. On the "*Specify stack details*" screen you should provide values for the
   following parameters of the CloudFormation stack:
   * **DomainName:** This is the name of your registered domain, such as example.com, for which you have an existed Route53 HostedZone configured.
   * **SubDomain:** This is the subdomain for your registered domain.  For www.example.com, the SubDomain is **www**
  

   When completed, click *Next*
5. [Configure stack options](https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/cfn-console-add-tags.html) if desired, then click *Next*.
6. On the review screen, you must check the boxes for:
   * "*I acknowledge that AWS CloudFormation might create IAM resources*" 
   * "*I acknowledge that AWS CloudFormation might create IAM resources
   with custom names*" 

   These are required to allow CloudFormation to create a Role to allow access
   to resources needed by the stack and name the resources in a dynamic way.
7. Choose *Create Change Set* 
8. On the *Change Set* screen, click *Execute* to launch your stack.
   * You may need to wait for the *Execution status* of the change set to
   become "*AVAILABLE*" before the "*Execute*" button becomes available.
9. Wait for the CloudFormation stack to launch. Completion is indicated when the "Stack status" is "*CREATE_COMPLETE*".
   * You can monitor the stack creation progress in the "Events" tab.


## Contributing

Contributions are more than welcome. Please read the [code of conduct](CODE_OF_CONDUCT.md) and the [contributing guidelines](CONTRIBUTING.md).

## License Summary

This project is licensed under the Apache-2.0 License.
