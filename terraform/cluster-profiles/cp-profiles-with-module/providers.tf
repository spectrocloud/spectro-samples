# Copyright (c) Spectro Cloud
# SPDX-License-Identifier: Apache-2.0

terraform {
  required_providers {
    spectrocloud = {
      version = ">= 0.17.2"
      source  = "spectrocloud/spectrocloud"
    }
    local = {
      source  = "hashicorp/local"
      version = ">= 2.4.0"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "6.71.0"
    }
  }

  required_version = ">= 1.5"
}

provider "spectrocloud" {
  project_name = "Default"
}