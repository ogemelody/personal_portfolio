resource "aws_s3_bucket" "portfolio" {
  bucket = "melodyegwuchukwu.com"

  website {
    index_document = "index.html"
    error_document = "index.html"
  }

  tags = {
    Name        = "PortfolioSite"
    Environment = "Production"
  }
}

resource "aws_s3_bucket_ownership_controls" "portfolio_ownership" {
  bucket = aws_s3_bucket.portfolio.id

  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_public_access_block" "portfolio_access" {
  bucket                  = aws_s3_bucket.portfolio.id
  block_public_acls        = false
  block_public_policy      = false
  ignore_public_acls       = false
  restrict_public_buckets  = false
}

resource "aws_s3_bucket_policy" "portfolio_policy" {
  bucket = aws_s3_bucket.portfolio.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "PublicReadGetObject"
        Effect    = "Allow"
        Principal = "*"
        Action    = ["s3:GetObject"]
        Resource  = "${aws_s3_bucket.portfolio.arn}/*"
      }
    ]
  })
}

# Upload your files from local folder
resource "aws_s3_object" "website_files" {
  for_each = fileset("${path.module}/website", "**")

  bucket       = aws_s3_bucket.portfolio.bucket
  key          = each.value
  source       = "${path.module}/website/${each.value}"
  etag         = filemd5("${path.module}/website/${each.value}")
  content_type = lookup(var.mime_types, regex("\\.[^.]+$", each.value), "text/plain")
}
