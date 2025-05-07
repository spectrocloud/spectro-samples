# Copyright (c) Spectro Cloud
# SPDX-License-Identifier: Apache-2.0

terraform {
  required_providers {
    spectrocloud = {
      version = ">= 0.23.05"
      source  = "spectrocloud/spectrocloud"
    }
    local = {
      source  = "hashicorp/local"
      version = ">= 2.5.2"
    }
  }

  required_version = ">= 1.10"
}

provider "spectrocloud" {
  project_name = "Default"
}
