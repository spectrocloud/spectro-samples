## Advanced Pattern

This pattern leverages Terraform modules to decouple the management of cluster profile versions from the cluster profile resource. Each cluster profile version is defined through a dedicated module. Terraform logic is applied to achieve unique cluster profile versions.

| Pros                                                                                                                     |
| ------------------------------------------------------------------------------------------------------------------------ |
| Reduces code duplication                                                                                                 |
| Adding or removing versions is a low complexity task                                                                     |
| Managing versions is an isolated task and does not impact other resources except clusters consuming the specific version |
| Accidental changes are less likely to occur                                                                              |
| Flexible and allows future changes to be made with minimal impact to existing code                                       |

| Cons                                                                                                                     |
| ------------------------------------------------------------------------------------------------------------------------ |
| Increased complexity that is offloaded to the module                                                                     |
| May be difficult to understand                                                                                           |
| YAML customization requires additional logic to support (Requires additional variable)                                   |
| Removing a version requires using the command `terraform destroy -target` where the specific version module is targeted. |
| Assumes all packs are defined in the same registry. Otherwise, additional logic is required.                             |

## Usage

1. To add a new version, create a new module in the `modules` directory. The module name should be the version number. For example, if you are adding version `1.0.0`, the module name would be `[your-module-name-1-0-0]`. Populate with all the required variables and resources.

```hcl
module "primary-cp-1-0-0" {
    source = "../cp-modules"

    name = "md-test"
    infrastructure_provider = "aws"
    cluster_profile_type = "cluster"
    registry_name = "Public Repo"
    profile_version = "1.0.0"
    pack_order = ["ubuntu-aws", "kubernetes","cni-calico", "csi-aws-ebs" ]
    packs = {
    "csi-aws-ebs" = "1.22.0"
    "cni-calico"  = "3.26.1"
    "kubernetes"  = "1.27.5"
    "ubuntu-aws"  = "22.04"
  }
}
```

2. The module requires you to explicity define the order of the packs. This is done through the `pack_order` variable. The order of the packs is important because it determines the order in which the packs are applied to the cluster. The first item in the list has the highest priority and the last item in the list has the lowest priority. This corresponds to the order in which the packs are applied to the cluster profile.

3. The module requires you to explicity define the pack name and version. This is done through the `packs` variable. The pack name and version are used to create the pack resource. You can also define the pack registry name through the `registry_name` variable. If the pack registry name is not defined, the default registry is used.

4. To add a new version to the cluster profile, add a new module resource to the `spectrocloud_cluster_profile` resource. The module name should be the version number. For example, if you are adding version `1.0.1`, the module name would be `[your-module-name-1-0-1]`.

```hcl
module "primary-cp-1-0-1" {
    source = "../cp-modules"

    name = "md-test"
    infrastructure_provider = "aws"
    cluster_profile_type = "cluster"
    registry_name = "Public Repo"
    profile_version = "1.0.1"
    pack_order = ["ubuntu-aws", "kubernetes","cni-calico", "csi-aws-ebs" ]
    packs = {
    "csi-aws-ebs" = "1.22.0"
    "cni-calico"  = "3.26.1"
    "kubernetes"  = "1.27.5"
    "ubuntu-aws"  = "22.04"
  }
}
```

5. To use the new version, update the `spectrocloud_cluster` resource to use the new version.

```hcl
resource "spectrocloud_cluster" "primary-cluster" {
  name             = "primary-cluster"
  cluster_profile  = module.primary-cp-1-0-1.id
 ....
}
```

> [!NOTE]
> You can also access all the exported attributes from the module. To search for an exported attribute, reference the module `module.primary-cp-1-0-1` and add a `.` to the end of the module name. This will display all the exported attributes, assuming your editor supports the Terraform language server.
