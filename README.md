# Azure Terraform Brownfield Migration

A hands-on brownfield infrastructure migration lab demonstrating how existing Azure resources can be brought under Terraform management without recreating the infrastructure.

The goal of this project was not to deploy a new environment. The Azure infrastructure already existed. The challenge was to discover the existing resources, understand Terraform import mechanics, generate Terraform configuration from the live Azure environment, troubleshoot generated configuration, migrate Terraform state to an Azure Storage backend, and finally verify that Terraform could manage the existing infrastructure with **zero infrastructure changes**.

---

## Project Objectives

This lab focused on learning the workflow used when Terraform is introduced into an environment that already contains infrastructure.

The objectives were to:

- Discover existing Azure resources using Azure CLI
- Understand Terraform resource addresses and Azure Resource IDs
- Understand Terraform `import` blocks
- Practice manual Terraform imports
- Understand why nested Azure resources may require separate discovery
- Use Microsoft Azure Export for Terraform (`aztfexport`)
- Generate Terraform configuration from existing Azure infrastructure
- Troubleshoot generated Terraform configuration
- Validate the imported Terraform configuration
- Migrate local Terraform state to Azure Blob Storage
- Verify the final environment using `terraform plan`
- Achieve a final result of **No changes**

---

# Architecture

The existing brownfield environment contained infrastructure such as:

```text
Azure Resource Group
│
├── Virtual Network
│   │
│   ├── Web Subnet
│   ├── App Subnet
│   └── DB Subnet
│
├── Network Security Groups
│   ├── Web NSG
│   ├── App NSG
│   └── DB NSG
│
├── Route Table
│   └── Routes
│
├── Public IP
│
├── Network Interfaces
│
├── Linux Virtual Machines
│   ├── Web VM
│   ├── App VM
│   └── DB VM
│
└── Azure Storage
    └── Terraform Remote State
```

The infrastructure already existed in Azure before Terraform began managing it.

That makes this a **brownfield migration**, rather than a greenfield deployment.

---

# Brownfield vs Greenfield

## Greenfield

Terraform creates infrastructure from scratch:

```text
Terraform Configuration
        ↓
terraform plan
        ↓
terraform apply
        ↓
Azure Resources
```

Terraform knows about the resources because Terraform created them.

## Brownfield

The infrastructure already exists:

```text
Existing Azure Resources
        ↓
Discover Resources
        ↓
Create/Generate Terraform Configuration
        ↓
Import Existing Resources into Terraform State
        ↓
Terraform Manages Existing Infrastructure
```

Terraform does **not automatically know** that an existing Azure resource corresponds to a resource block in the Terraform configuration.

The resource must be connected to Terraform state through an import process.

---

# Step 1 — Authenticate to Azure

The first step was authenticating Azure CLI.

```bash
az login
```

After authentication, Azure CLI displayed the active tenant and subscription.

The correct subscription is important because Terraform and Azure Export for Terraform must inspect the same Azure environment containing the existing resources.

---

# Step 2 — Initialize Terraform

Terraform was initialized:

```bash
terraform init
```

This downloaded the AzureRM provider and initialized the Terraform working directory.

Example result:

```text
Terraform has been successfully initialized!
```

---

# Step 3 — Discover Existing Azure Resources

Before importing anything, I first needed to understand what already existed.

Azure CLI was used to list resources in the resource group.

```bash
az resource list \
  --resource-group <RESOURCE-GROUP> \
  --query "[].{Name:name, Type:type, ID:id}" \
  -o table
```

This command was extremely useful for brownfield discovery.

### Command breakdown

```text
az resource list
```

Lists Azure resources.

```text
--resource-group
```

Limits the search to a specific resource group.

```text
--query
```

Uses a JMESPath query to select the fields that are useful for the migration.

```text
Name:name
Type:type
ID:id
```

Displays:

- Resource name
- Azure resource type
- Full Azure Resource ID

```text
-o table
```

Formats the result into a readable table.

The **Azure Resource ID** is especially important because Terraform imports use the actual Azure Resource ID to identify the existing resource.

---

# Step 4 — Discover Subnets Separately

One important lesson was that a general resource listing does not necessarily show every nested resource in the way needed for Terraform migration.

Subnets are child resources of a Virtual Network.

They were listed separately using:

```bash
az network vnet subnet list \
  --resource-group <RESOURCE-GROUP> \
  --vnet-name brownfield-vnet \
  --query "[].{Name:name, Prefix:addressPrefix, ID:id}" \
  -o table
```

This returned the existing subnets such as:

```text
web-subnet
app-subnet
db-subnet
```

and their full Azure Resource IDs.

### Important lesson

Brownfield discovery is not always:

```text
az resource list
```

and done.

Nested resources may require service-specific Azure CLI commands.

---

# Step 5 — Understand Terraform Import Blocks

Before using automation, I practiced the Terraform import mechanism manually.

Example:

```hcl
import {
  to = azurerm_virtual_network.brownfield
  id = "/subscriptions/.../resourceGroups/.../providers/Microsoft.Network/virtualNetworks/brownfield-vnet"
}
```

The two most important pieces are:

```text
to
```

and

```text
id
```

## `to`

```hcl
to = azurerm_virtual_network.brownfield
```

This is the **Terraform resource address**.

It means:

> Store this Azure resource in Terraform state under this Terraform resource address.

It is Terraform's name/reference for the resource.

## `id`

```hcl
id = "/subscriptions/.../virtualNetworks/brownfield-vnet"
```

This is the **actual Azure Resource ID**.

It tells Terraform exactly which real Azure object should be imported.

The mental model I used was:

```text
to = Terraform's address/name for the resource

id = Actual existing Azure resource
```

Therefore:

```text
Terraform Address
        ↓
        ↔
Existing Azure Resource ID
```

The import operation connects the two.

---

# Step 6 — Resources Considered During Manual Import

During the manual portion of the lab, I worked through resources such as:

```text
Virtual Network
Subnets
Network Security Groups
Route Table
Routes
Public IP
Network Interfaces
Virtual Machines
```

This helped demonstrate why manually migrating a large brownfield environment can become time-consuming.

For a small environment, manually writing imports is manageable.

For environments containing hundreds or thousands of resources, automation becomes much more useful.

---

# Understanding Network Interfaces

An important concept reviewed during the lab was the role of the Azure Network Interface (NIC).

A VM does not simply attach directly to a subnet.

Conceptually:

```text
Virtual Machine
      ↓
Network Interface (NIC)
      ↓
Subnet
      ↓
Virtual Network
```

The NIC contains the VM's network connectivity information.

Depending on the environment, it may be associated with:

- Private IP configuration
- Public IP
- Subnet
- Network Security Group

Therefore NICs are important resources when importing an existing Azure VM environment into Terraform.

---

# Understanding Route Tables and Routes

Another important distinction was between a route table and the routes inside it.

The route table is a resource:

```text
Route Table
```

The individual routes are separate Terraform-managed objects.

Conceptually:

```text
Route Table
│
├── Route 1
├── Route 2
└── Route 3
```

The route table can then be associated with a subnet.

For example:

```text
App Subnet
    ↓
Route Table
    ↓
Custom Route
```

This means a complete brownfield migration may require importing:

- Route table
- Individual routes
- Subnet-to-route-table association

---

# Step 7 — Terraform Generated Configuration Experiment

Terraform's configuration-generation functionality was also tested using:

```bash
terraform plan -generate-config-out=generated.tf
```

The purpose was to generate Terraform configuration for imported resources.

However, the generated VM configuration produced conflicts.

One example involved:

```hcl
os_managed_disk_id
```

being generated together with arguments that cannot coexist with it.

Errors included conflicts between:

```text
os_managed_disk_id
source_image_reference
source_image_id
admin_username
admin_password
storage_account_type
```

Terraform reported errors similar to:

```text
Invalid combination of arguments
```

and:

```text
Conflicting configuration arguments
```

This demonstrated an important brownfield lesson:

> Automatically generated Terraform configuration should be reviewed and validated rather than blindly trusted.

---

# Step 8 — Switch to Azure Export for Terraform

Instead of manually creating every import block, I switched to Microsoft's **Azure Export for Terraform (`aztfexport`)**.

This is much more practical when migrating a resource group containing many existing resources.

The tool was not initially installed.

---

# Step 9 — Installing Azure Export for Terraform

The system used Linux x86_64.

Architecture was verified using:

```bash
uname -m
```

Result:

```text
x86_64
```

The latest Azure Export for Terraform release was identified from its GitHub release information.

The Linux AMD64 package was downloaded and extracted.

After installation, the binary was placed in:

```text
/usr/local/bin/
```

Verification:

```bash
aztfexport --version
```

Result during this lab:

```text
aztfexport version v0.20.0
```

This confirmed the tool was successfully installed.

---

# Step 10 — Export the Existing Resource Group

A dedicated directory was created:

```bash
mkdir export
```

Azure Export for Terraform was then run against the existing resource group.

The command syntax required the resource group name as a positional argument:

```bash
aztfexport resource-group \
  <RESOURCE-GROUP-NAME> \
  --output-dir ./export
```

An earlier attempt incorrectly used:

```bash
--resource-group
```

which resulted in:

```text
flag provided but not defined: -resource-group
```

Reading the command help showed the correct syntax:

```text
aztfexport resource-group [option] <resource group name>
```

This was a useful troubleshooting lesson:

> When a CLI flag fails, read the command's built-in usage output instead of guessing the syntax.

---

# Step 11 — Azure Export Interactive Resource Review

Azure Export for Terraform discovered the resources in the resource group.

The interactive interface displayed the Azure Resource IDs and their corresponding Terraform resource addresses.

The export contained approximately 31 discovered items during the lab.

Some resources were imported while some unsupported or unnecessary items were skipped.

After reviewing the resources, the export was saved.

Azure Export reported:

```text
Terraform state and the config are generated at: ./export
```

---

# Step 12 — Files Generated by Azure Export

Inside the export directory:

```bash
cd export
ls -la
```

Azure Export generated files including:

```text
main.tf
provider.tf
terraform.tf
terraform.tfstate
.terraform.lock.hcl
aztfexportResourceMapping.json
aztfexportSkippedResources.txt
```

## `main.tf`

Contains the generated Terraform resource definitions.

## `provider.tf`

Contains the AzureRM provider configuration.

## `terraform.tf`

Contains Terraform-level configuration such as the required provider and backend configuration.

## `terraform.tfstate`

Contains Terraform's mapping between Terraform resource addresses and the actual Azure resources.

## `aztfexportResourceMapping.json`

Contains information about how Azure resources were mapped to Terraform resources.

## `aztfexportSkippedResources.txt`

Records resources that Azure Export skipped.

---

# Step 13 — Generated Resource Names

Azure Export automatically generated Terraform resource addresses such as:

```text
azurerm_linux_virtual_machine.res-1
azurerm_linux_virtual_machine.res-2
azurerm_linux_virtual_machine.res-3
azurerm_network_interface.res-4
```

These names are functional but are not ideal for long-term maintainability.

A production cleanup/refactoring phase could later rename resources into meaningful Terraform addresses such as:

```hcl
azurerm_linux_virtual_machine.web
azurerm_linux_virtual_machine.app
azurerm_linux_virtual_machine.db
```

State-safe refactoring would be required when renaming Terraform resource addresses.

---

# Step 14 — Troubleshooting Generated VM Configuration

Running:

```bash
terraform validate
```

revealed conflicts in the generated Linux VM configuration.

The key problem was:

```hcl
os_managed_disk_id
```

appearing alongside configuration used for defining a VM from an image.

Terraform reported conflicts involving:

```text
source_image_reference
source_image_id
admin_username
admin_password
os_disk.storage_account_type
```

The generated configuration therefore required cleanup before Terraform could successfully validate it.

---

# Step 15 — Using `sed` to Remove the Conflicting Argument

Instead of manually editing the same line across several VM resource blocks, I used `sed`.

Command:

```bash
sed -i '/^[[:space:]]*os_managed_disk_id[[:space:]]*=/d' main.tf
```

### Command breakdown

```text
sed
```

Stream editor used to modify text.

```text
-i
```

Edit the file **in place**.

```text
^
```

Beginning of the line.

```text
[[:space:]]*
```

Match zero or more whitespace characters.

```text
os_managed_disk_id
```

Match this Terraform argument.

```text
[[:space:]]*=
```

Allow spaces before the equals sign.

```text
d
```

Delete the matching line.

```text
main.tf
```

File being modified.

Therefore this command means:

> Find every line in `main.tf` defining `os_managed_disk_id` and delete that entire line.

It does **not** replace the text with an empty value.

It removes the entire matching line.

---

# Step 16 — Fix Generated Placeholder Passwords

The generated VM configuration also contained:

```hcl
admin_password = "ignored-as-imported"
```

Terraform still validates the value even though the VM had already been imported.

The placeholder failed AzureRM password complexity validation.

Since the password value was not required for the imported configuration being retained, the generated `admin_password` lines were removed from the Terraform configuration.

This eliminated another generated configuration validation issue.

---

# Step 17 — Format and Validate

After cleaning the generated configuration:

```bash
terraform fmt
```

Then:

```bash
terraform validate
```

The configuration could then be evaluated normally by Terraform.

This reinforces an important workflow:

```text
Generate
   ↓
Review
   ↓
Clean
   ↓
terraform fmt
   ↓
terraform validate
   ↓
terraform plan
```

Generated infrastructure-as-code should still go through normal Terraform validation.

---

# Step 18 — Terraform Plan

The critical validation step was:

```bash
terraform plan
```

Terraform refreshed all imported resources from Azure and compared:

```text
Terraform configuration
        ↕
Terraform state
        ↕
Real Azure infrastructure
```

The final result was:

```text
No changes. Your infrastructure matches the configuration.
```

Terraform also reported:

```text
Terraform has compared your real infrastructure against your configuration and found no differences, so no changes are needed.
```

This was the key success condition for the lab.

It confirmed that the existing Azure environment had been represented in Terraform without Terraform attempting to recreate or modify the infrastructure.

---

# Step 19 — Configure Azure Remote State

The export initially used a local backend:

```hcl
terraform {
  backend "local" {}
}
```

A local backend stores Terraform state on the machine running Terraform.

That is not ideal for a shared or production-style workflow.

The backend was therefore changed to Azure Blob Storage.

Conceptually:

```text
Local terraform.tfstate
        ↓
terraform init -migrate-state
        ↓
Azure Storage Account
        ↓
Blob Container
        ↓
brownfield-migration/terraform.tfstate
```

The AzureRM backend configuration identifies information such as:

```hcl
terraform {
  backend "azurerm" {
    resource_group_name  = "<RESOURCE-GROUP>"
    storage_account_name = "<STORAGE-ACCOUNT>"
    container_name       = "tfstate"
    key                  = "brownfield-migration/terraform.tfstate"
  }
}
```

The `key` determines the blob path/name used for the Terraform state.

---

# Step 20 — Migrate Existing State

Because Terraform already had local state containing the imported resources, the backend was not simply reinitialized.

The existing state needed to be migrated.

Command:

```bash
terraform init -migrate-state
```

This tells Terraform:

> The backend changed. Move the existing Terraform state to the newly configured backend.

After initialization Terraform reported:

```text
Terraform has been successfully initialized!
```

---

# Step 21 — Verify Terraform State

The imported resources were checked with:

```bash
terraform state list
```

The state contained resources including:

```text
azurerm_linux_virtual_machine
azurerm_network_interface
azurerm_network_security_group
azurerm_network_security_rule
azurerm_public_ip
azurerm_resource_group
azurerm_route
azurerm_route_table
azurerm_storage_account
azurerm_subnet
azurerm_subnet_network_security_group_association
azurerm_subnet_route_table_association
azurerm_virtual_network
```

This verified that Terraform state knew about the existing Azure resources.

---

# Step 22 — Verify Remote State in Azure

The Azure Storage container was inspected from Azure.

The Terraform state appeared under:

```text
tfstate/
└── brownfield-migration/
    └── terraform.tfstate
```

This confirmed that the local brownfield state had successfully been migrated to the Azure backend.

---

# Step 23 — Final Validation

The final verification was:

```bash
terraform plan
```

Result:

```text
No changes. Your infrastructure matches the configuration.
```

That completed the brownfield migration.

---

# Final Brownfield Workflow

The full workflow learned in this project was:

```text
Existing Azure Infrastructure
            ↓
       az login
            ↓
Discover Resources with Azure CLI
            ↓
Understand Resource IDs
            ↓
Understand Terraform Import Blocks
            ↓
Practice Manual Import
            ↓
Recognize Manual Import Scaling Problem
            ↓
Install Azure Export for Terraform
            ↓
aztfexport resource-group
            ↓
Generate Terraform Configuration + State
            ↓
Review Generated Configuration
            ↓
Troubleshoot Provider Conflicts
            ↓
Clean Generated Configuration
            ↓
terraform fmt
            ↓
terraform validate
            ↓
terraform plan
            ↓
NO CHANGES
            ↓
Configure AzureRM Remote Backend
            ↓
terraform init -migrate-state
            ↓
Azure Blob Remote State
            ↓
terraform state list
            ↓
terraform plan
            ↓
NO CHANGES
```

---

# Troubleshooting Summary

Several issues occurred during the lab, which made the project more realistic.

## Problem 1 — `aztfexport` unavailable through APT

Attempting to install the package directly did not work:

```text
Unable to locate package aztfexport
```

### Resolution

The appropriate Linux release was downloaded from the Azure Export for Terraform GitHub releases and installed manually.

---

## Problem 2 — Wrong `aztfexport` resource-group syntax

Initial command syntax attempted to use:

```text
--resource-group
```

The CLI returned:

```text
flag provided but not defined: -resource-group
```

### Resolution

The help output showed that the resource group name is a positional argument:

```bash
aztfexport resource-group <RESOURCE-GROUP-NAME>
```

---

## Problem 3 — Output Directory Already Contained Files

Azure Export warned:

```text
The output directory is not empty.
```

### Lesson

Brownfield export tools should ideally write into a clean directory to avoid mixing generated Terraform configuration with unrelated or previous files.

---

## Problem 4 — Generated VM Disk Conflicts

Terraform reported:

```text
Invalid combination of arguments
```

because generated VM configuration contained incompatible combinations involving:

```text
os_managed_disk_id
source_image_reference
source_image_id
admin_username
admin_password
storage_account_type
```

### Resolution

The conflicting generated `os_managed_disk_id` lines were removed.

```bash
sed -i '/^[[:space:]]*os_managed_disk_id[[:space:]]*=/d' main.tf
```

---

## Problem 5 — Generated Password Failed Validation

Generated configuration contained:

```hcl
admin_password = "ignored-as-imported"
```

The AzureRM provider validated this value and rejected it because it did not satisfy the required password complexity rules.

### Resolution

The unnecessary generated `admin_password` entries were removed from the imported configuration.

---

## Problem 6 — Moving Local State to Azure

Azure Export initially generated local Terraform state.

Simply changing the backend does not represent the complete migration process.

### Resolution

The state was migrated using:

```bash
terraform init -migrate-state
```

The state was then verified in Azure Blob Storage.

---

# Important Commands Learned

```bash
# Azure authentication
az login

# Discover resources
az resource list \
  --resource-group <RESOURCE-GROUP> \
  --query "[].{Name:name, Type:type, ID:id}" \
  -o table

# Discover VNet subnets
az network vnet subnet list \
  --resource-group <RESOURCE-GROUP> \
  --vnet-name brownfield-vnet \
  --query "[].{Name:name, Prefix:addressPrefix, ID:id}" \
  -o table

# Terraform initialization
terraform init

# Generate configuration from import blocks
terraform plan -generate-config-out=generated.tf

# Verify CPU architecture
uname -m

# Verify Azure Export for Terraform
aztfexport --version

# Export Azure resource group
aztfexport resource-group \
  <RESOURCE-GROUP-NAME> \
  --output-dir ./export

# Remove conflicting generated argument
sed -i '/^[[:space:]]*os_managed_disk_id[[:space:]]*=/d' main.tf

# Format Terraform
terraform fmt

# Validate Terraform
terraform validate

# Compare Terraform with Azure
terraform plan

# Migrate state to remote backend
terraform init -migrate-state

# Inspect resources managed in Terraform state
terraform state list
```

---

# Git Security

Terraform state must never be committed to Git because it can contain sensitive infrastructure information.

The project uses `.gitignore` to exclude:

```gitignore
.terraform/
*.tfstate
*.tfstate.*
*.tfplan
*.tfvars
*.tfvars.json
crash.log
crash.*.log
override.tf
override.tf.json
*_override.tf
*_override.tf.json
.terraformrc
terraform.rc
*.bak
*.pem
id_rsa
id_ed25519
```

The Terraform dependency lock file is intentionally committed:

```text
.terraform.lock.hcl
```

This helps keep provider selections consistent.

---

# Key Lessons

### 1. Terraform state is the bridge between Terraform and real infrastructure

Writing Terraform configuration alone does not make Terraform manage an existing Azure resource.

The resource must exist in Terraform state.

### 2. `to` and `id` solve different problems

```text
to = Terraform resource address
id = Real Azure Resource ID
```

Import connects them.

### 3. Brownfield discovery matters

Before importing infrastructure, understand what exists and how the resources relate to each other.

### 4. Nested resources may require separate discovery

Subnets, routes, associations, and similar resources may require specific Azure CLI commands or additional inspection.

### 5. Manual import is valuable to understand

Manually writing import blocks teaches how Terraform actually maps existing infrastructure into state.

### 6. Automation becomes valuable at scale

Writing imports manually for a few resources is reasonable.

Writing them for hundreds of resources is not.

Tools such as Azure Export for Terraform can accelerate the initial migration.

### 7. Generated Terraform is a starting point

`aztfexport` can dramatically accelerate brownfield migration, but generated code should still be:

```text
Reviewed
Validated
Cleaned
Refactored
Tested
```

### 8. `terraform plan` is the final truth check

For this migration, the desired final result was:

```text
No changes.
```

That demonstrated that Terraform's configuration and state matched the existing Azure environment.

### 9. Remote state should be used for serious Terraform environments

The lab finished by moving the state from the local machine into Azure Blob Storage.

This creates a better foundation for future team workflows and CI/CD.

---

# Result

The project successfully converted an existing Azure environment into Terraform-managed infrastructure without rebuilding it.

Final verification:

```text
Existing Azure Resources
        +
Generated/Cleaned Terraform Configuration
        +
Imported Terraform State
        +
Azure Blob Remote Backend
        ↓
terraform plan
        ↓
No changes
```

The lab provided hands-on experience with one of the most important Terraform scenarios beyond greenfield deployment:

**adopting existing cloud infrastructure into Infrastructure as Code.**

---

## Next Steps

This project was intentionally focused on learning brownfield migration.

Future Terraform labs will return to building infrastructure directly with Terraform and progressively introduce:

- Variables and locals
- `for_each`
- `count`
- Conditional expressions
- Maps and objects
- Reusable modules
- Data sources
- Azure remote state
- Git feature branches
- Pull requests
- CI validation
- Security scanning
- Controlled Terraform apply
- OIDC-based Azure authentication
- CI/CD workflows

The goal is to progressively move from basic Terraform resource creation toward production-style Azure Infrastructure as Code workflows.
