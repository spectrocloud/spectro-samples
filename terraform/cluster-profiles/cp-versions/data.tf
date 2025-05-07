# Copyright (c) Spectro Cloud
# SPDX-License-Identifier: Apache-2.0

data "spectrocloud_registry" "public_registry" {
  name = "Public Repo"
}

// A public Helm registry
data "spectrocloud_registry" "our_helm_registry" {
  name = "Public Spectro Helm Repo"
}


# Uncomment this if you are using a cloud account
# data "spectrocloud_cloudaccount_aws" "account" {
#   name = var.aws_cloud_account_name
# }



data "spectrocloud_pack" "csi-aws-ebs" {
  count        = length([for version, pack in local.packs : version if contains(keys(pack), "csi-aws-ebs")])
  name         = "csi-aws-ebs"
  version      = [for version, pack in local.packs : pack["csi-aws-ebs"] if contains(keys(pack), "csi-aws-ebs")][count.index]
  registry_uid = data.spectrocloud_registry.public_registry.id
}

data "spectrocloud_pack" "cni-calico" {
  count        = length([for version, pack in local.packs : version if contains(keys(pack), "cni-calico")])
  name         = "cni-calico"
  version      = [for version, pack in local.packs : pack["cni-calico"] if contains(keys(pack), "cni-calico")][count.index]
  registry_uid = data.spectrocloud_registry.public_registry.id
}

data "spectrocloud_pack" "kubernetes" {
  count        = length([for version, pack in local.packs : version if contains(keys(pack), "kubernetes")])
  name         = "kubernetes"
  version      = [for version, pack in local.packs : pack["kubernetes"] if contains(keys(pack), "kubernetes")][count.index]
  registry_uid = data.spectrocloud_registry.public_registry.id
}

data "spectrocloud_pack" "ubuntu-aws" {
  count        = length([for version, pack in local.packs : version if contains(keys(pack), "ubuntu-aws")])
  name         = "ubuntu-aws"
  version      = [for version, pack in local.packs : pack["ubuntu-aws"] if contains(keys(pack), "ubuntu-aws")][count.index]
  registry_uid = data.spectrocloud_registry.public_registry.id
}


data "spectrocloud_pack" "cni-cilium-oss" {
  count        = length([for version, pack in local.packs : version if contains(keys(pack), "cni-cilium-oss")])
  name         = "cni-cilium-oss"
  version      = [for version, pack in local.packs : pack["cni-cilium-oss"] if contains(keys(pack), "cni-cilium-oss")][count.index]
  registry_uid = data.spectrocloud_registry.public_registry.id
}

data "spectrocloud_pack" "scaffold" {
  count        = length([for version, pack in local.packs : version if contains(keys(pack), "scaffold")])
  name         = "scaffold"
  version      = [for version, pack in local.packs : pack["scaffold"] if contains(keys(pack), "scaffold")][count.index]
  registry_uid = data.spectrocloud_registry.our_helm_registry.id
}


