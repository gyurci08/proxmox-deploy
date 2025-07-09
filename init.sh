#!/usr/bin/env bash
set -Eeuo pipefail

###############################################################################
# Proxmox Landscape Automated Init Script
# - Loads config.yml and exports variables as env vars
# - Runs Ansible and Terraform with centralized config
###############################################################################

# === CONSTANTS ===
readonly SCRIPT_DIR="$(dirname "$(realpath -s "${BASH_SOURCE[0]}")")"
readonly SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"
readonly CURRENT_DATE="$(date +%Y-%m-%d_%H-%M-%S)"
readonly LOG_PREFIX="[PROXMOX_LANDSCAPE_INIT]"
readonly REQUIRED_BINS=("ansible-playbook" "terraform" "yq")
readonly CONFIG_FILE="${SCRIPT_DIR}/config.yml"
readonly ANSIBLE_DIR="${SCRIPT_DIR}/01_ansible_deploy_templates"
readonly ANSIBLE_PLAYBOOK="playbooks/deploy_vm_template.yml"
readonly TERRAFORM_DIR="${SCRIPT_DIR}/02_terraform_deploy_vms"

# === GLOBALS ===
CURRENT_DIR=""

# === FUNCTIONS ===

log_header() {
    printf '\n%*s\n' "${COLUMNS:-50}" '' | tr ' ' '='
    echo "${LOG_PREFIX} ➤ $*"
    printf '%*s\n' "${COLUMNS:-50}" '' | tr ' ' '='
}

log_info() {
    echo "$(date +"%Y-%m-%dT%H:%M:%S%:z") - [INFO] ${LOG_PREFIX} $*"
}

log_error() {
    echo "$(date +"%Y-%m-%dT%H:%M:%S%:z") - [ERROR] ${LOG_PREFIX} $*" >&2
}

validate_binaries() {
    for bin in "${REQUIRED_BINS[@]}"; do
        if ! command -v "$bin" &>/dev/null; then
            log_error "Required binary '$bin' is not installed or not in PATH"
            exit 1
        fi
    done
}

safe_pushd() {
    if ! pushd "$1" > /dev/null; then
        log_error "Failed to change directory to $1"
        exit 10
    fi
    CURRENT_DIR="$1"
}

safe_popd() {
    if ! popd > /dev/null; then
        log_error "Failed to return to previous directory"
        exit 11
    fi
    CURRENT_DIR=""
}

cleanup() {
    if [[ -n "$CURRENT_DIR" ]]; then
        log_info "Cleaning up: returning to original directory"
        safe_popd
    fi
}

trap 'log_error "An unexpected error occurred. Exiting."; cleanup' ERR
trap 'cleanup' EXIT

load_config_yml() {
  local config_file="$1"
  # Use yq to get all top-level keys
  local keys
  IFS=$'\n' read -d '' -r -a keys < <(yq e 'keys | .[]' "$config_file" && printf '\0')
  for key in "${keys[@]}"; do
    # Special handling for SSH keys
    if [[ "$key" == "CLOUD_INIT_SSH_PUBLIC_KEYS" ]]; then
      # Try as multiline string
      local value
      value=$(yq -r ".${key}" "$config_file")
      # If it's a YAML list, join with newlines
      if yq e ".${key} | type" "$config_file" | grep -q '!!seq'; then
        value=$(yq -r ".${key}[]" "$config_file" | sed ':a;N;$!ba;s/\n/\\n/g')
        value="${value//\\n/
}"
      fi
      export CLOUD_INIT_SSH_PUBLIC_KEYS="$value"
      export TF_VAR_cloud_init_ssh_public_keys="$value"
    else
      # For other keys, export as usual
      local value
      value=$(yq -r ".${key}" "$config_file")
      export "$key=$value"
      local tf_key="TF_VAR_$(echo "$key" | tr '[:upper:]' '[:lower:]')"
      export "$tf_key=$value"
    fi
  done
}

run_ansible_playbook() {
    log_info "Changing directory to $ANSIBLE_DIR"
    safe_pushd "$ANSIBLE_DIR"
    log_info "Running Ansible playbook: $ANSIBLE_PLAYBOOK"
    if ! ansible-playbook "$ANSIBLE_PLAYBOOK"; then
        log_error "Ansible playbook failed. Exiting."
        safe_popd
        exit 2
    fi
    safe_popd
}

run_terraform_apply() {
    log_info "Changing directory to $TERRAFORM_DIR"
    safe_pushd "$TERRAFORM_DIR"
    log_info "Initializing Terraform"
    if ! terraform init; then
        log_error "Terraform init failed. Exiting."
        safe_popd
        exit 3
    fi
    log_info "Applying Terraform plan"
    if ! terraform apply -auto-approve; then
        log_error "Terraform apply failed. Exiting."
        safe_popd
        exit 4
    fi
    safe_popd
}

# === MAIN ===

log_header "Starting Proxmox Automated Landscape Install"

validate_binaries

log_info "Loading config from $CONFIG_FILE"
load_config_yml "$CONFIG_FILE"
log_info "Exported variables from $CONFIG_FILE: PROXMOX_NODE=$PROXMOX_NODE"
printf '%s\n' "$CLOUD_INIT_SSH_PUBLIC_KEYS"
run_ansible_playbook
run_terraform_apply

log_header "Setup complete! Check Proxmox Web UI and SSH access to your VM."
log_info "Date: $CURRENT_DATE"
log_info "Script: $SCRIPT_NAME"
