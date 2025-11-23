output "website_url" {
  value = aws_s3_bucket.portfolio.website_domain
  description = "S3 Static Website URL"
}
output "cloudfront_domain" {
value = aws_cloudfront_distribution.cdn.domain_name
}