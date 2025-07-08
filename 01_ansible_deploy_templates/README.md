# Proxmox Automated Template Install

This guide describes a robust workflow for preparing Proxmox with Ansible and then provisioning VMs using Terraform. It ensures repeatability, security, and flexibility for infrastructure automation.

## 1. Robot User Configuration

*Variables:*  
`VAR_USER=robot`  
`VAR_ROLE=Robot`

```bash
VAR_USER=automation
VAR_ROLE=Automation
pveum role add ${VAR_ROLE} -privs "
VM.Allocate,
VM.Clone,
VM.Config.CDROM,
VM.Config.CPU,
VM.Config.Cloudinit,
VM.Config.Disk,
VM.Config.HWType,
VM.Config.Memory,
VM.Config.Network,
VM.Config.Options,
VM.Monitor,
VM.Audit,
VM.PowerMgmt,
Datastore.AllocateSpace,
Datastore.Audit,
SDN.Allocate,
SDN.Use,
SDN.Audit
"
useradd -m -s /bin/bash -G sudo ${VAR_USER} && pveum user add ${VAR_USER}@pam && passwd ${VAR_USER}
pveum aclmod / -user ${VAR_USER}@pam -role ${VAR_ROLE}
```

## 2. Ansible Playbooks

**Vault Configuration**

```bash
ansible-vault create group_vars/all/vault.yml
ansible-vault edit group_vars/all/vault.yml
```

**Router Template Setup**

```bash
ansible-playbook playbooks/1_rtr_template.yml --ask-vault-pass
```

**Guest Template Setup**

```bash
ansible-playbook playbooks/2_vm_template.yml --ask-vault-pass
```

## 3. Post-Installation

**Cloned Router: Expanding the rootfs**

```bash
opkg update
opkg install parted losetup resize2fs
wget -U "" -O expand-root.sh "https://openwrt.org/_export/code/docs/guide-user/advanced/expand_root?codeblock=0"
. ./expand-root.sh
```

## 4. Example `vault.yml`

```yaml
# Proxmox host details
PROXMOX_NODE: "example"
PROXMOX_HOST: "192.168.0.100"
PROXMOX_SSH_PORT: "22"
PROXMOX_USER: "robot"
PROXMOX_PASSWORD: "..."
PROXMOX_API_KEY: "..."
PROXMOX_SSH_KEY: "~/.ssh/proxmox_ecdsa"

# Cloud-init details   
CLOUD_INIT_USER: admin
CLOUD_INIT_PASSWORD: "..."
SSH_PUBLIC_KEYS: |
  ssh-rsa AAAA...
```

## 5. Terraform Workflow (After Ansible)

After the Proxmox and template preparation with Ansible, use Terraform for automated, repeatable VM provisioning.

### a. Directory Structure

```
terraform/
├── variables.tf
├── provider.tf
├── main.tf
├── secrets.auto.tfvars
```

### b. Provider Configuration (`provider.tf`)

```hcl
terraform {
  required_providers {
    proxmox = {
      source  = "telmate/proxmox"
      version = ">= 2.9.6"
    }
  }
}

provider "proxmox" {
  pm_api_url          = "https://your-proxmox-host:8006/api2/json"
  pm_api_token_id     = var.pm_api_token_id
  pm_api_token_secret = var.pm_api_token_secret
  pm_tls_insecure     = true
}
```

### c. Variables (`variables.tf`)

```hcl
variable "pm_api_token_id" {
  description = "Proxmox API token ID"
  type        = string
  sensitive   = true
}

variable "pm_api_token_secret" {
  description = "Proxmox API token secret"
  type        = string
  sensitive   = true
}

variable "vm_ssh_public_key" {
  description = "SSH public key for the VM"
  type        = string
}
```

### d. Secrets (`secrets.auto.tfvars`)

```hcl
pm_api_token_id     = "your_token_id"
pm_api_token_secret = "your_token_secret"
vm_ssh_public_key   = "ssh-rsa AAAA..."
```

### e. Main Resource (`main.tf`)

```hcl
resource "proxmox_vm_qemu" "test-1" {
  name        = "test-1"
  target_node = "jgy-dev-proxmox"
  clone       = "template-suse-Leap-15.6"
  cores       = 2
  memory      = 2048
  os_type     = "cloud-init"

  disk {
    storage = "local-lvm"
    size    = "10G"
    type    = "virtio"
    backup  = true
  }

  network {
    model  = "virtio"
    bridge = "vmbr0"
  }

  ipconfig0 = "ip=10.0.1.140/24,gw=10.0.1.254"
  sshkeys   = var.vm_ssh_public_key
}
```

### f. Terraform Usage

1. **Initialize Terraform**
   ```bash
   terraform init
   ```

2. **Preview the Plan**
   ```bash
   terraform plan
   ```

3. **Apply the Configuration**
   ```bash
   terraform apply
   ```

4. **Destroy Resources (Optional)**
   ```bash
   terraform destroy
   ```

## Best Practices

- Store sensitive data only in vaults or `.tfvars` files excluded from version control.
- Use variables for all environment-specific values for flexibility.
- Assign only the minimal necessary privileges to the robot user/token.

This workflow ensures a clean, secure, and repeatable process for provisioning Proxmox VMs using Ansible for template preparation and Terraform for deployment.