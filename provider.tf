terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 3.0"
    }
  }
  required_version = ">= 1.3.0"
}

provider "aws" {
  region = "eu-central-1" #  region
}

# For ACM (CloudFront), must create cert in us-east-1
provider "aws" {
  alias  = "use1"
  region = "us-east-1"
}

variable "cloudflare_api_token" {
  description = "API token for Cloudflare"
  type        = string
  sensitive   = true
}

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}
