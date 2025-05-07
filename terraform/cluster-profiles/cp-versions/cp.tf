# Copyright (c) Spectro Cloud
# SPDX-License-Identifier: Apache-2.0

resource "spectrocloud_cluster_profile" "aws-profile" {
  count = length(local.cp-versions)

  name = "tf-aws-profile-${local.cp-versions[count.index]}" // If you don't want multiple profiles, you can use a single profile for all versions. Remove the count.index from the name as shown below.
  # name        = "tf-aws-profile"
  description = "A basic cluster profile for AWS"
  tags        = concat(var.tags, ["env:aws", "version:${local.cp-versions[count.index]}"])
  cloud       = "aws"
  type        = "cluster"
  version     = local.cp-versions[count.index]


  dynamic "pack" {
    for_each = local.packs[local.cp-versions[count.index]]

    content {
      name = pack.key
      tag  = pack.value

      uid = local.pack_data[pack.key].data_source[
        index(
          [for v, p in local.packs : p[pack.key] if contains(keys(p), pack.key)],
          pack.value
        )
      ].id

      // Use coalesce to handle the case where there is no values file provided
      // Otherwise, use the values from the pack data source. We have to iterate over the correct data source instance as 
      // each version has its own data source instance.
      values = coalesce(
        try(
          file("${path.module}/${pack.key}/${pack.value}.yaml"),
          null
        ), // Try to load version-specific values file from pack folder
        local.pack_data[pack.key].data_source[
          index(
            [for v, p in local.packs : p[pack.key] if contains(keys(p), pack.key)],
            pack.value
          )
        ].values
      )

    }
  }


  depends_on = [
    data.spectrocloud_pack.cni-calico,
    data.spectrocloud_pack.csi-aws-ebs,
    data.spectrocloud_pack.kubernetes,
    data.spectrocloud_pack.ubuntu-aws,
    data.spectrocloud_pack.cni-cilium-oss,
    data.spectrocloud_pack.scaffold
  ]
}
