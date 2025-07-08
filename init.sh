#!/usr/bin/env bash
set -Eeuo pipefail

## CONSTANTS ###################################################################
readonly SCRIPT_DIR="$(dirname "$(realpath -s "${BASH_SOURCE[0]}")")"
readonly SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"
readonly CURRENT_DATE="$(date +%Y-%m-%d_%H-%M-%S)"
readonly LOG_PREFIX="[PROXMOX_LANDSCAPE_INIT]"
readonly REQUIRED_BINS=("ansible-playbook" "terraform")

# Ansible and Terraform directories
readonly ANSIBLE_DIR="${SCRIPT_DIR}/01_ansible_deploy_templates"
readonly ANSIBLE_PLAYBOOK="playbooks/2_vm_template.yml"
readonly TERRAFORM_DIR="${SCRIPT_DIR}/02_terraform_deploy_vms"

## GLOBALS #####################################################################
CURRENT_DIR=""

## FUNCTIONS ###################################################################

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

# Safe pushd/popd wrapper to ensure directory stack is managed properly
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

# Cleanup function to be called on script exit
cleanup() {
    if [[ -n "$CURRENT_DIR" ]]; then
        log_info "Cleaning up: returning to original directory"
        safe_popd
    fi
}

# Trap ERR and EXIT signals
trap 'log_error "An unexpected error occurred. Exiting."; cleanup' ERR
trap 'cleanup' EXIT

run_ansible_playbook() {
    log_info "Changing directory to $ANSIBLE_DIR"
    safe_pushd "$ANSIBLE_DIR"
    log_info "Running Ansible playbook: $ANSIBLE_PLAYBOOK"
    if ! ansible-playbook "$ANSIBLE_PLAYBOOK" --ask-vault-pass; then
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
    if ! echo yes | terraform apply; then
        log_error "Terraform apply failed. Exiting."
        safe_popd
        exit 4
    fi
    safe_popd
}

## MAIN ########################################################################

log_header "Starting Proxmox Automated Landscape Install"

validate_binaries
run_ansible_playbook
run_terraform_apply

log_header "Setup complete! Check Proxmox Web UI and SSH access to your VM."
log_info "Date: $CURRENT_DATE"
log_info "Script: $SCRIPT_NAME"
