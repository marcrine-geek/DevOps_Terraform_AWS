provider "aws" {
  region = "us-east-1"
}

// creating s3 bucket for trail logs
resource "aws_s3_bucket" "bucketname" {
  bucket = "bucketname"
  acl    = "private"
  
// bucket policy to allow cloud trail logs
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AWSCloudTrailAclCheck",
      "Effect": "Allow",
      "Principal": {
        "Service": "cloudtrail.amazonaws.com"
      },
      "Action": "s3:GetBucketAcl",
      "Resource": "arn:aws:s3:::bucketname"
    },
    {
      "Sid": "AWSCloudTrailWrite",
      "Effect": "Allow",
      "Principal": {
        "Service": "cloudtrail.amazonaws.com"
      },
      "Action": "s3:PutObject",
      "Resource": "arn:aws:s3:::bucketname/*",
      "Condition": {
        "StringEquals": {
          "s3:x-amz-acl": "bucket-owner-full-control"
        }
      }
    }
  ]
}
EOF
}

// creating cloud trail

resource "aws_cloudtrail" "trail-name" {
  name = "trail-name"

  s3_bucket_name = aws_s3_bucket.mycloudtrailbucketmarcrine.id
  is_multi_region_trail = true
}
