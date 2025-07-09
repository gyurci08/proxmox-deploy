# Proxmox Automated Landscape Install

This project enables fully automated Proxmox VM deployment and management using a single command and a centralized configuration file. All environment-specific values are managed in `config.yml`, and the process is orchestrated via the `init.sh` script.

## 1. Prerequisites

### Proxmox User, Role, and API Token Setup

Before running the automation, you must create a dedicated Proxmox user, assign a custom role with the necessary privileges, and generate an API token. This ensures secure, least-privilege automation.

**Steps:**

1. **Create a Custom Role**  
   Assign only the permissions required for VM management and automation:
   ```bash
   pveum role add RobotRole -privs "
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
   ```

2. **Create the User**
   ```bash
   useradd -m -s /bin/bash -G sudo robot
   pveum user add robot@pam
   passwd robot
   ```

3. **Assign the Role to the User**
   ```bash
   pveum aclmod / -user robot@pam -role RobotRole
   ```

4. **Create an API Token for Automation**
   ```bash
   pveum user token add robot@pam automation
   # Note: Store the displayed token ID and secret securely.
   ```

**Record these values** (API ID, API Key/Secret, username, etc.) in your `config.yml` for use by the automation.

## 2. Centralized Configuration

Edit `config.yml` with your environment details:

```yaml
# Proxmox host details
PROXMOX_NODE: "proxmox-node-1"
PROXMOX_HOST: "proxmox-node-1.local"
PROXMOX_SSH_PORT: "22"
PROXMOX_USER: "robot"
PROXMOX_PASSWORD: "12345678"
PROXMOX_API_ID: "robot@pam!robot"
PROXMOX_API_KEY: "e123456b-1234-1234-1234-612345678901"
PROXMOX_SSH_KEY: "/home/user/.ssh/id.proxmox-node-1"

# Cloud-init details   
CLOUD_INIT_USER: "admin"
CLOUD_INIT_PASSWORD: "12345678"
CLOUD_INIT_SEARCHDOMAIN: "internal.local"
CLOUD_INIT_NAMESERVER: "192.168.1.254"
CLOUD_INIT_SSH_PUBLIC_KEYS: |
  ecdsa-sha2-nistp521 AAAA12345678rVw== user@user-pc
```

## 3. Usage: One-Command Automation

From your project root, run:

```bash
./init.sh
```

This will:

- Validate required binaries.
- Load and export all variables from `config.yml` as both standard environment variables and `TF_VAR_` variables (for Terraform).
- Run the Ansible playbook to prepare Proxmox templates.
- Run Terraform to deploy and configure VMs using the same variables.

## 4. Variable Flow

| Source      | Bash/Env Var         | Terraform Variable (auto)   | Ansible Usage (lookup)            |
|-------------|---------------------|-----------------------------|-----------------------------------|
| config.yml  | PROXMOX_HOST        | TF_VAR_proxmox_host         | `lookup('env', 'PROXMOX_HOST')`   |
| config.yml  | CLOUD_INIT_USER     | TF_VAR_cloud_init_user      | `lookup('env', 'CLOUD_INIT_USER')`|
| ...         | ...                 | ...                         | ...                               |

## 5. Best Practices

- **Edit only `config.yml`** to change environment-specific values.
- **Store secrets** only in `config.yml`; never commit sensitive files to version control.
- **Check logs:** The script logs each step and errors for easy troubleshooting.
- **For SSH keys:** Can use multi-line values in `config.yml`.

## 6. Troubleshooting

- If a variable is missing in Ansible or Terraform, ensure it is present in `config.yml` and follows the format.
- Install any missing tools as prompted by the script.

## 7. Example Workflow

1. **Create Proxmox user, role, and API token** as described above.
2. **Edit `config.yml`** with your environment details and credentials.
3. **Run the automation:**
   ```bash
   ./init.sh
   ```
4. **Check Proxmox Web UI** and verify VMs are created and accessible.

This workflow ensures a single source of truth for all automation variables and a reproducible, one-command setup for your Proxmox landscape. Adjust `config.yml` for new environments or credentials as needed.