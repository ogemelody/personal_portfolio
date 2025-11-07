output "website_url" {
  value = aws_s3_bucket.portfolio.website_endpoint
  description = "S3 Static Website URL"
}
