## Intermediate Pattern

The intermediate pattern of managing and maintain cluster profiles. Each cluster profile version is defined through a single `spectrocloud_cluster_profile` resource. Terraform logic is applied to achieve unique cluster profile versions.

| Pros                                         |
| -------------------------------------------- |
| Reduces code duplication                     |
| Adding new versions is a low complexity task |

| Cons                                                                                                               |
| ------------------------------------------------------------------------------------------------------------------ |
| Requires more complex Terraform logic                                                                              |
| Difficult to understand                                                                                            |
| Removing versions is difficult as cluster profiles are recreated. This us due to state being maintained in a list. |

## Usage

1. List the number of versions desired in the `locals.cp-versions` variable.

```hcl
cp-versions    = ["1.0.0", "1.0.1", "1.0.3"]
```

2. List each versions pack name and pack version in the `locals.cp-packs` variable.

```hcl
  packs = {
    "1.0.0" = {
      "csi-aws-ebs" = "1.22.0"
      "cni-calico"  = "3.26.1"
      "kubernetes"  = "1.27.5"
      "ubuntu-aws"  = "22.04"
    }
    "1.0.1" = {
      "csi-aws-ebs" = "1.24.0"
      "cni-calico"  = "3.26.1"
      "kubernetes"  = "1.27.5"
      "ubuntu-aws"  = "22.04"
    }
    "1.0.3" = {
      "csi-aws-ebs"    = "1.24.0"
      "cni-cilium-oss" = "1.14.3"
      "kubernetes"     = "1.28.3"
      "ubuntu-aws"     = "22.04"
    }
  }

```

3. Add a data resouce for each defined pack. Replace the name of the pack with the name of the pack you are adding. For example, if you are adding the `csi-aws-ebs` pack, the data resource would look like the following:

```hcl
data "spectrocloud_pack" "csi-aws-ebs" {
  count        = length([for version, pack in local.packs : version if contains(keys(pack), "csi-aws-ebs")])
  name         = "csi-aws-ebs"
  version      = [for version, pack in local.packs : pack["csi-aws-ebs"] if contains(keys(pack), "csi-aws-ebs")][count.index]
  registry_uid = data.spectrocloud_registry.public_registry.id
}
```

4. Add a local variable that contains a reference to the respective data resource. This is required for the dynamic behavior of the `spectrocloud_cluster_profile` resource. Add or remove packs as needed.

```hcl
  pack_data = {
    "csi-aws-ebs" = {
      data_source = data.spectrocloud_pack.csi-aws-ebs
    }
    "cni-calico" = {
      data_source = data.spectrocloud_pack.cni-calico
    }
    "kubernetes" = {
      data_source = data.spectrocloud_pack.kubernetes
    }
    "ubuntu-aws" = {
      data_source = data.spectrocloud_pack.ubuntu-aws
    }
    "cni-cilium-oss" = {
      data_source = data.spectrocloud_pack.cni-cilium-oss
    }
  }
```

5. Change the node variables to the desired values. AWS is used as an example but the concept applies to other cloud providers.

6. Specify the desired cluster profile version when deploying a cluster. You can use a target variable or manually specify the version. In the example below, the target variable `target_version` is used.

```hcl
cluster_profile {
    id = spectrocloud_cluster_profile.aws-profile[index(local.cp-versions, local.target_version)].id
  }
```

7. If you want to provide a YAML file for a pack, create a folder with the name of the pack and add the YAML file to the folder. The YAML file will be used for the specified version. In this example, the `scaffold` pack is used. The folder is named `scaffold` and the each version of the pack has its own YAML file with the version number as the file name.

```
scaffold/
├── 0.1.0.yaml
├── 0.1.1.yaml
```
