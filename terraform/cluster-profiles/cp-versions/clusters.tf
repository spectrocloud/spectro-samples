# Copyright (c) Spectro Cloud
# SPDX-License-Identifier: Apache-2.0

# resource "spectrocloud_cluster_aws" "aws-cluster" {

#   name             = "aws-cluster"
#   tags             = concat(var.tags, ["env:aws", "service:hello-universe-frontend"])
#   cloud_account_id = data.spectrocloud_cloudaccount_aws.account.id

#   cloud_config {
#     region       = var.aws_region
#     ssh_key_name = var.aws_key_pair_name
#   }

#   cluster_profile {
#     id = spectrocloud_cluster_profile.aws-profile[index(local.cp-versions, local.target_version)].id
#   }

#   machine_pool {
#     control_plane           = true
#     control_plane_as_worker = true
#     name                    = "control-plane-pool"
#     count                   = var.aws_control_plane_nodes.count
#     instance_type           = var.aws_control_plane_nodes.instance_type
#     disk_size_gb            = var.aws_control_plane_nodes.disk_size_gb
#     azs                     = var.aws_control_plane_nodes.availability_zones
#   }

#   machine_pool {
#     name          = "worker-pool"
#     count         = var.aws_worker_nodes.count
#     instance_type = var.aws_worker_nodes.instance_type
#     disk_size_gb  = var.aws_worker_nodes.disk_size_gb
#     azs           = var.aws_worker_nodes.availability_zones
#   }

#   timeouts {
#     create = "30m"
#     delete = "15m"
#   }
# }
