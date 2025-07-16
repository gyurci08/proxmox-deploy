#!/usr/bin/env bash
set -Eeuo pipefail

###############################################################################
# Proxmox Landscape Automated Controller Script
# Loads config.yml and exports variables as env vars. Integrates Ansible & Terraform flows.
###############################################################################

# --- Constants ---
readonly SCRIPT_DIR="$(dirname "$(realpath -s "${BASH_SOURCE[0]}")")"
readonly SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"
readonly CURRENT_DATE="$(date +%Y-%m-%d_%H-%M-%S)"
readonly LOG_PREFIX="[PROXMOX_LANDSCAPE_MANAGE]"
readonly REQUIRED_BINS=("ansible-playbook" "terraform" "yq")
readonly CONFIG_FILE="${SCRIPT_DIR}/config.yml"
readonly ANSIBLE_DEPLOY_DIR="${SCRIPT_DIR}/01_ansible_deploy_templates"
readonly ANSIBLE_CONFIGURE_DIR="${SCRIPT_DIR}/03_ansible_configure_guests"
readonly ANSIBLE_DEPLOY_PLAYBOOK="playbooks/deploy_vm_template.yml"
readonly ANSIBLE_CONFIGURE_PLAYBOOK="playbooks/configure_guests.yml"
readonly TERRAFORM_DIR="${SCRIPT_DIR}/02_terraform_deploy_guests"

# --- Globals ---
CURRENT_DIR=""

readonly USAGE="Usage: $SCRIPT_NAME <deploy|manage|destroy|terraform {validate|plan|apply|destroy}|ansible {deploy|configure}>"

# --- Logging ---
log_header() {
    printf '\n%*s\n' "${COLUMNS:-60}" '' | tr ' ' '='
    echo "${LOG_PREFIX} ➤ $*"
    printf '%*s\n' "${COLUMNS:-60}" '' | tr ' ' '='
}
log_info()   { echo "$(date +"%Y-%m-%dT%H:%M:%S%:z") - [INFO]  ${LOG_PREFIX} $*"; }
log_error()  { echo "$(date +"%Y-%m-%dT%H:%M:%S%:z") - [ERROR] ${LOG_PREFIX} $*" >&2; }

# --- Utility Functions ---
validate_binaries() {
    for bin in "${REQUIRED_BINS[@]}"; do
        if ! command -v "$bin" &>/dev/null; then
            log_error "Required binary '$bin' is not installed or not in PATH."
            exit 1
        fi
    done
}

safe_pushd() {
    if ! pushd "$1" > /dev/null; then
        log_error "Failed to cd to $1"
        exit 10
    fi
    CURRENT_DIR="$1"
}

safe_popd() {
    if [[ -n "$CURRENT_DIR" ]]; then
        if ! popd > /dev/null; then
            log_error "Failed to popd from $CURRENT_DIR"
            exit 11
        fi
        CURRENT_DIR=""
    fi
}

cleanup() {
    [[ -n "$CURRENT_DIR" ]] && {
        log_info "Cleaning up: returning to previous directory"
        safe_popd
    }
}

trap 'log_error "Trapped UNEXPECTED error. Cleaning up & exiting."; cleanup; exit 99' ERR
trap 'cleanup' EXIT

# --- YAML Config Loader: Supports existing (inherited/env) vars ---
load_config_yml() {
    local config_file="$1" key value tf_key
    while IFS= read -r key; do
        # skip if already set as env or exported
        if [[ -z "${!key:-}" ]]; then
            if [[ $(yq e ".\"$key\" | type" "$config_file") == "!!seq" ]]; then
                value=$(yq -r ".\"$key\"[]" "$config_file" | paste -sd $'\n' -)
            else
                value=$(yq -r ".\"$key\"" "$config_file")
            fi
            export "$key"="$value"
            tf_key="TF_VAR_$(echo "$key" | tr '[:upper:]' '[:lower:]')"
            export "$tf_key"="$value"
        fi
    done < <(yq e 'keys | .[]' "$config_file")
}

clear_vm_ssh_hostkeys() {
    log_info "Removing stale SSH host keys for VMs..."
    local tf_file="${TERRAFORM_DIR}/main.tf"
    [[ ! -f "$tf_file" ]] && { log_error "Terraform main.tf not found. Skipping SSH host key cleanup."; return; }
    grep ipconfig0 "$tf_file" | sed -nE 's/.*ipconfig0 *= *"ip=([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+)\/.*/\1/p' \
        | sort -u | while read -r ip; do
        [[ -n "$ip" ]] && {
            log_info "Removing known_hosts entry for $ip"
            ssh-keygen -f "$HOME/.ssh/known_hosts" -R "$ip" >/dev/null 2>&1 || true
        }
    done
}

# --- Task Runners ---

run_ansible_playbook() {
    local playbook_dir="$1"
    local playbook="$2"
    log_info "Changing directory to $playbook_dir"
    safe_pushd "$playbook_dir"
    log_info "Running Ansible playbook: $playbook"
    ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook "$playbook"
    safe_popd
}

run_terraform_command() {
    local subcommand="$1"
    log_info "Changing directory to $TERRAFORM_DIR"
    safe_pushd "$TERRAFORM_DIR"
    log_info "Initializing Terraform"
    terraform init
    case "$subcommand" in
      validate)  log_info "Validating Terraform configuration"; terraform validate ;;
      plan)      log_info "Planning Terraform changes"; terraform plan ;;
      apply)     log_info "Applying Terraform plan"; terraform apply -auto-approve ;;
      destroy)   log_info "Destroying Terraform-managed infrastructure"; terraform destroy -auto-approve ;;
      *)         echo "$USAGE"; safe_popd; exit 1 ;;
    esac
    safe_popd
}

# --- Main Dispatcher ---
main() {
    [[ $# -lt 1 ]] && { echo "$USAGE"; exit 1; }

    validate_binaries
    clear_vm_ssh_hostkeys

    [[ ! -f "$CONFIG_FILE" ]] && { log_error "Config file $CONFIG_FILE not found!"; exit 1; }
    log_info "Loading config from $CONFIG_FILE"
    load_config_yml "$CONFIG_FILE"

    case "$1" in
        deploy)
            log_header "Proxmox Automated Landscape Install"
            # Deploy OpenWrt template
            DISTRIBUTION="openwrt" run_ansible_playbook "$ANSIBLE_DEPLOY_DIR" "$ANSIBLE_DEPLOY_PLAYBOOK"
            # Deploy Guest template
            run_ansible_playbook "$ANSIBLE_DEPLOY_DIR" "$ANSIBLE_DEPLOY_PLAYBOOK"
            # Deploy vms
            run_terraform_command apply
            # Configure SALT
            run_ansible_playbook "$ANSIBLE_CONFIGURE_DIR" "$ANSIBLE_CONFIGURE_PLAYBOOK"
            ;;
        manage)
            log_header "Proxmox Automated Landscape Management"
            # Deploy vms
            run_terraform_command apply
            # Configure SALT
            run_ansible_playbook "$ANSIBLE_CONFIGURE_DIR" "$ANSIBLE_CONFIGURE_PLAYBOOK"
            ;;
        destroy)
            log_header "Proxmox Automated Landscape Destroy"
            run_terraform_command destroy
            ;;
        terraform)
            case "${2:-}" in
                validate|plan|apply|destroy) run_terraform_command "$2" ;;
                *) echo "$USAGE"; exit 1 ;;
            esac
            ;;
        ansible)
            case "${2:-}" in
                deploy)
                    DISTRIBUTION="openwrt" run_ansible_playbook "$ANSIBLE_DEPLOY_DIR" "$ANSIBLE_DEPLOY_PLAYBOOK"
                    run_ansible_playbook "$ANSIBLE_DEPLOY_DIR" "$ANSIBLE_DEPLOY_PLAYBOOK" 
                    ;;
                configure) 
                    run_ansible_playbook "$ANSIBLE_CONFIGURE_DIR" "$ANSIBLE_CONFIGURE_PLAYBOOK"
                    ;;
                *) echo "$USAGE"; exit 1 ;;
            esac
            ;;
        *)
            echo "Unknown command: $1"
            echo "$USAGE"
            exit 1
            ;;
    esac

    log_header "Setup complete! Check Proxmox Web UI and SSH access to your VM."
    log_info   "Date: $CURRENT_DATE"
    log_info   "Script: $SCRIPT_NAME"
}

main "$@"
