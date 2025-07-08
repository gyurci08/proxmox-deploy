## Proxmox Automated Landscape Install

### 1. Robot User Configuration

*Variables*:  
`VAR_USER=robot`  
`VAR_ROLE=Robot`

```bash
VAR_USER=robot
VAR_ROLE=Robot
pveum role add ${VAR_ROLE} -privs "
Datastore.AllocateSpace,
Datastore.Audit,
Pool.Allocate,
SDN.Allocate,
SDN.Audit,
SDN.Use,
Sys.Audit,
Sys.Console,
Sys.Modify,
VM.Allocate,
VM.Audit,
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
VM.Migrate,
VM.PowerMgmt
"
useradd -m -s /bin/bash -G sudo ${VAR_USER} && pveum user add ${VAR_USER}@pam && passwd ${VAR_USER}
pveum aclmod / -user ${VAR_USER}@pam -role ${VAR_ROLE}
```

### 2. Ansible Playbooks

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

### 3. Post-Installation

**Cloned Router: Expanding the rootfs**

```bash
opkg update
opkg install parted losetup resize2fs
wget -U "" -O expand-root.sh "https://openwrt.org/_export/code/docs/guide-user/advanced/expand_root?codeblock=0"
. ./expand-root.sh
```

### 4. Examples

**vault.yml**

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

## 5. Terraform Usage After Ansible

After the Ansible-based template preparation, you can automate VM deployment and configuration on Proxmox using Terraform. Below is a best-practice workflow and example configuration.

### a. Directory Structure

```
terraform/
├── provider.tf
├── variables.tf
├── secrets.auto.tfvars
├── main.tf
```

### b. Provider Configuration (`provider.tf`)

### c. Variables (`variables.tf`)

```hcl
variable "pm_api_token_id" {}
variable "pm_api_token_secret" {}
variable "vm_ssh_public_key" {}
```

### d. Secrets (`secrets.auto.tfvars`)

```hcl
pm_api_url          = "https://192.168.0.100:8006/api2/json"
pm_api_token_id     = "robot@pam!terraform"
pm_api_token_secret = "your_token_secret"
target_node         = "example"
template_name       = "ubuntu-template"
vm_name             = "landscape-vm"
vm_ip               = "10.0.1.140"
vm_gw               = "10.0.1.254"
ssh_public_key      = "ssh-rsa AAAA..."
```

### e. Main Resource (`main.tf`)

```hcl
resource "proxmox_vm_qemu" "landscape" {
  name        = var.vm_name
  target_node = var.target_node
  clone       = var.template_name
  cores       = var.cores
  memory      = var.memory
  os_type     = "cloud-init"

  disk {
    storage = var.storage
    size    = "32G"
    type    = "virtio"
    backup  = true
  }

  network {
    model  = "virtio"
    bridge = var.network_bridge
  }

  ipconfig0 = "ip=${var.vm_ip}/24,gw=${var.vm_gw}"
  sshkeys   = var.ssh_public_key
}
```

### f. Terraform Workflow

1. **Initialize Terraform**
   ```bash
   terraform init
   ```

2. **Preview Changes**
   ```bash
   terraform plan
   ```

3. **Apply Configuration**
   ```bash
   terraform apply
   ```

4. **Check Proxmox Web UI**
   - Confirm that the VM is created, configured, and accessible via SSH.

5. **Tear Down (if needed)**
   ```bash
   terraform destroy
   ```

### g. Best Practices

- Store sensitive data (API tokens, passwords) only in vaults or `.tfvars` files excluded from version control.
- Use variables for all environment-specific values.
- Ensure your Proxmox template VM has a cloud-init disk for proper initialization.
- Assign only the minimal necessary privileges to the robot user/token.

This approach provides a clear, repeatable infrastructure-as-code workflow for deploying and managing Proxmox VMs after your initial Ansible-based template preparation.