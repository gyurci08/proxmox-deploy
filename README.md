# Proxmox Automated Landscape Install

This project enables fully automated Proxmox VM deployment and management using a single command and a centralized configuration file. All environment-specific values are managed in `config.yml`, and the process is orchestrated via the `controller.sh` script.

### 0. Dependencies

This project requires the following tools installed:

- `ansible`
- `terraform`
- `yq` (mikefarah)

Please ensure these dependencies are installed before running the `controller.sh` script.

### 1. Robot User Configuration


1. **Create a Role and a User** 

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

2. **Create an API Token for the user**

```bash
pveum user token add robot@pam automation
```

## 2. Centralized Configuration

Edit `config.yml` with your environment details:

```yaml
# Proxmox host details
PROXMOX_NODE: "proxmox"
PROXMOX_HOST: "proxmox.local"
PROXMOX_SSH_PORT: "22"
PROXMOX_USER: "robot"
PROXMOX_PASSWORD: "12345678"
PROXMOX_API_ID: "robot@pam!robot"
PROXMOX_API_KEY: "12345678-1234-1234-1234-123456789123"
PROXMOX_SSH_KEY: "/home/user/.ssh/id-robot"

# OS details
DISTRIBUTION: "suse" # Available: suse, ubuntu

# Cloud-init details   
CLOUD_INIT_USER: "user"
CLOUD_INIT_PASSWORD: "12345678"
CLOUD_INIT_SEARCHDOMAIN: "local"
CLOUD_INIT_GATEWAY: "10.0.1.254"
CLOUD_INIT_NAMESERVER: "10.0.1.254"
CLOUD_INIT_SSH_KEY: "/home/user/.ssh/id"
CLOUD_INIT_SSH_PUBLIC_KEYS: |
  ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQCasdS53KFrGg6yIcuQ== user
  
# Guest configure details
SALT_MASTER_HOSTNAME: "vm-master"
SALT_MASTER_IP: "10.0.1.140"
```

## 3. Usage

From your project root, run:

```bash
./controller.sh 
```

### Supported Commands

| Command                             | Description                                                                                          |
|--------------------------------------|------------------------------------------------------------------------------------------------------|
| `deploy`                            | Prepares Proxmox templates (Ansible), deploys VMs (Terraform), configures guests (Ansible)           |
| `manage`                            | Applies current Terraform configuration, then configures guests                                      |
| `destroy`                           | Destroys all Terraform-managed infrastructure                                                        |
| `terraform validate/plan/apply/destroy` | Run Terraform with the given subcommand                                                           |
| `ansible deploy`                    | Only prepares Proxmox VM templates with Ansible                                                      |
| `ansible configure`                 | Only configures guest VMs with Ansible                                                               |

**Examples:**
```bash
./controller.sh deploy
./controller.sh manage
./controller.sh destroy
./controller.sh terraform plan
./controller.sh ansible deploy
./controller.sh ansible configure
```

## 4. Variable Flow

| Source      | Bash/Env Var         | Terraform Variable (auto)   | Ansible Usage (lookup)            |
|-------------|----------------------|-----------------------------|-----------------------------------|
| config.yml  | PROXMOX_HOST         | TF_VAR_proxmox_host         | `lookup('env', 'PROXMOX_HOST')`   |
| config.yml  | CLOUD_INIT_USER      | TF_VAR_cloud_init_user      | `lookup('env', 'CLOUD_INIT_USER')`|
| ...         | ...                  | ...                         | ...                               |

## 5. Best Practices

- **Edit only** `config.yml` to change environment-specific values.
- **Store secrets** only in `config.yml`. **Never commit sensitive files to version control.**
- **Check logs:** The script outputs detailed logs for all steps and errors.
- **Multi-line SSH keys:** You can use multi-line values in `config.yml`.

## 6. Troubleshooting

- If a variable is missing in Ansible or Terraform, ensure it is present in `config.yml` and follows the correct format.
- Install any missing tools as prompted by the script.

## 7. Example Workflow

1. **Create Proxmox user, role, and API token** as described above.
2. **Edit `config.yml`** with your environment details and credentials.
3. **Run the automation:**
   ```bash
   ./controller.sh deploy
   ```
4. **Check Proxmox Web UI** and verify VMs are created and accessible.

**This workflow ensures a single source of truth for all automation variables and a reproducible, one-command setup for your Proxmox landscape. Adjust `config.yml` for new environments or credentials as needed.**