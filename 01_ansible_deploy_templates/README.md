## Proxmox Automated Template Install

### 1. Robot User Configuration
*Variables*:  
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

### 2. Ansible Playbooks
**Vault Configuration**  
```bash
ansible-vault create group_vars/all/vault.yml
```

```bash
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

**Cloned Router**

Expanding the rootfs:

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