#############################################
# S3 BUCKET (PRIVATE, USED ONLY BY CLOUDFRONT)
#############################################

resource "aws_s3_bucket" "portfolio" {
  bucket = var.domain

  tags = {
    Name        = "PortfolioSite"
    Environment = "Production"
  }
}

resource "aws_s3_bucket_ownership_controls" "ownership" {
  bucket = aws_s3_bucket.portfolio.id

  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_public_access_block" "public_access" {
  bucket                  = aws_s3_bucket.portfolio.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Upload website files
resource "aws_s3_object" "website_files" {
  for_each = fileset("${path.module}/website", "**")

  bucket       = aws_s3_bucket.portfolio.bucket
  key          = each.value
  source       = "${path.module}/website/${each.value}"
  etag         = filemd5("${path.module}/website/${each.value}")

  content_type = lookup(
    var.mime_types,
    regex("\\.[^.]+$", each.value),
    "text/plain"
  )
}

#############################################
# CLOUDFRONT ORIGIN ACCESS IDENTITY (OAI)
#############################################

resource "aws_cloudfront_origin_access_identity" "oai" {
  comment = "OAI for ${var.domain}"
}

data "aws_iam_policy_document" "s3_policy_for_cf" {
  statement {
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = [aws_cloudfront_origin_access_identity.oai.iam_arn]
    }

    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.portfolio.arn}/*"]
  }
}

resource "aws_s3_bucket_policy" "bucket_policy" {
  bucket = aws_s3_bucket.portfolio.id
  policy = data.aws_iam_policy_document.s3_policy_for_cf.json
}

#############################################
# ACM CERTIFICATE (must be in us-east-1)
#############################################

resource "aws_acm_certificate" "cloudfront_cert" {
  provider          = aws.use1
  domain_name       = var.domain
  validation_method = "DNS"

  subject_alternative_names = [
    "www.${var.domain}"
  ]

  lifecycle {
    create_before_destroy = true
  }
}

# Create ACM DNS validation records inside Cloudflare
resource "cloudflare_record" "acm_validation" {
  for_each = {
    for dvo in aws_acm_certificate.cloudfront_cert.domain_validation_options :
    dvo.domain_name => {
      name  = dvo.resource_record_name
      type  = dvo.resource_record_type
      value = dvo.resource_record_value
    }
  }

  zone_id = var.cloudflare_zone_id
  name    = each.value.name
  type    = each.value.type
  value   = each.value.value
  ttl     = 120
}

resource "aws_acm_certificate_validation" "cert_validation" {
  provider                = aws.use1
  certificate_arn         = aws_acm_certificate.cloudfront_cert.arn
  validation_record_fqdns = [for r in cloudflare_record.acm_validation : r.hostname]
}

#############################################
# CLOUDFRONT DISTRIBUTION
#############################################

resource "aws_cloudfront_distribution" "cdn" {
  enabled = true
  comment = "CloudFront for ${var.domain}"

  aliases = [
    var.domain,
    "www.${var.domain}"
  ]

  origin {
    domain_name = aws_s3_bucket.portfolio.bucket_regional_domain_name
    origin_id   = "s3-${aws_s3_bucket.portfolio.id}"

    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.oai.cloudfront_access_identity_path
    }
  }

  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "s3-${aws_s3_bucket.portfolio.id}"
    viewer_protocol_policy = "redirect-to-https"

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }
  }

  custom_error_response {
    error_code         = 403
    response_code      = 200
    response_page_path = "/index.html"
  }

  custom_error_response {
    error_code         = 404
    response_code      = 200
    response_page_path = "/index.html"
  }

  price_class     = "PriceClass_100"
  is_ipv6_enabled = true

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate.cloudfront_cert.arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  depends_on = [
    aws_s3_bucket_policy.bucket_policy,
    aws_acm_certificate_validation.cert_validation
  ]
}

#############################################
# CLOUDFLARE DNS → CLOUDFront
#############################################

resource "cloudflare_record" "root" {
  zone_id = var.cloudflare_zone_id
  name    = "@"
  type    = "CNAME"
  value   = aws_cloudfront_distribution.cdn.domain_name
  proxied = true
}

resource "cloudflare_record" "www" {
  zone_id = var.cloudflare_zone_id
  name    = "www"
  type    = "CNAME"
  value   = aws_cloudfront_distribution.cdn.domain_name
  proxied = true
}
