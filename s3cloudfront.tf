/*provider "aws" {
  region  = "us-east-2"
  profile = "default"
}*/

resource "aws_s3_bucket" "b" {
  bucket = "kanchantfbucket"
  acl    = "private"

/*  provisioner "local-exec" {
    command = "aws s3 cp /Users/kanchandafane/downloads/quino-al-5WMkrgjCzFo-unsplash.jpg s3://${aws_s3_bucket.b.id}/images/sunset.jpg"
  }
*/

  tags = {
    Name = "My Terraform bucket"
  }
}

locals {
  s3_origin_id = "myS3Origin"
}

resource "aws_cloudfront_origin_access_identity" "origin_access_identity" {
  comment = "This is for S3 access"
}

resource "aws_cloudfront_distribution" "s3_distribution" {
  origin {
    domain_name = aws_s3_bucket.b.bucket_regional_domain_name
    origin_id   = local.s3_origin_id
    origin_path = "/images"
    s3_origin_config {
  		origin_access_identity = aws_cloudfront_origin_access_identity.origin_access_identity.cloudfront_access_identity_path
  	}
  }

  enabled             = true
  is_ipv6_enabled     = true
  comment             = "Lab Cloud Front"
  default_root_object = "index.html"

  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = local.s3_origin_id

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "allow-all"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }
  
restrictions {
    geo_restriction {
      restriction_type = "blacklist"
      locations        = ["US", "CA", "GB", "DE"]
    }
  }

  price_class = "PriceClass_All"

  tags = {
    Environment = "development"
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}

data "aws_iam_policy_document" "origin" {

  statement {
    sid = "S3GetObjectForCloudFront"

    actions   = ["s3:GetObject"]
    resources = ["arn:aws:s3:::${aws_s3_bucket.b.id}/images/*"]

    principals {
      type        = "AWS"
      identifiers = [ aws_cloudfront_origin_access_identity.origin_access_identity.iam_arn ]
    }
  }
}

resource "aws_s3_bucket_policy" "policy" {
  bucket = aws_s3_bucket.b.id
  policy = data.aws_iam_policy_document.origin.json
}

output "cfdetails"{
 value = aws_cloudfront_distribution.s3_distribution.domain_name
}

/*
output "s3origin"{
 value = aws_cloudfront_origin_access_identity.origin_access_identity
}

output "s3iampolicy"{
 value = aws_s3_bucket_policy.policy
}
*/