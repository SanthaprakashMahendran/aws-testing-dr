# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

terraform {


  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.47.0"
    }

    random = {
      source  = "hashicorp/random"
      version = "~> 3.6.1"
    }

    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0.5"
    }

    cloudinit = {
      source  = "hashicorp/cloudinit"
      version = "~> 2.3.4"
    }
  }
  

  backend "s3" {
    bucket  = "my-terraform-state-bucket-989-987"
    key     = "eks/dr/terraform.tfstate"
    region  = "us-east-1"
    encrypt = true
  }

  required_version = "~> 1.3"
}
