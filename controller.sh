#!/usr/bin/env bash
set -Eeuo pipefail

###############################################################################
# Proxmox Landscape Automated Controller Script
# - Loads config.yml and exports variables as env vars
# - Runs Ansible and Terraform with centralized config
# - Supports: deploy, manage, destroy, terraform {validate|plan|apply|destroy}, ansible {deploy|configure}
###############################################################################

# === CONSTANTS ===
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

# === GLOBALS ===
CURRENT_DIR=""

# === HELP MESSAGE ===
USAGE="Usage: $SCRIPT_NAME <deploy | manage | destroy | terraform {validate|plan|apply|destroy} | ansible {deploy|configure}>"

# === LOGGING ===
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

# === UTILS ===
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

# === CONFIG LOADING ===
load_config_yml() {
    local config_file="$1"
    local key value tf_key
    while IFS= read -r key; do
        if [[ $(yq e ".\"$key\" | type" "$config_file") == "!!seq" ]]; then
            value=$(yq -r ".\"$key\"[]" "$config_file" | paste -sd $'\n' -)
        else
            value=$(yq -r ".\"$key\"" "$config_file")
        fi
        export "$key=$value"
        tf_key="TF_VAR_$(echo "$key" | tr '[:upper:]' '[:lower:]')"
        export "$tf_key=$value"
    done < <(yq e 'keys | .[]' "$config_file")
}

# === RUNNERS ===
run_ansible_playbook() {
    local playbook_dir="$1"
    local playbook="$2"
    log_info "Changing directory to $playbook_dir"
    safe_pushd "$playbook_dir"
    log_info "Running Ansible playbook: $playbook"
    if ! ansible-playbook "$playbook"; then
        log_error "Ansible playbook failed. Exiting."
        safe_popd
        exit 2
    fi
    safe_popd
}

run_ansible_playbook_nohostkey() {
    local playbook_dir="$1"
    local playbook="$2"
    log_info "Changing directory to $playbook_dir"
    safe_pushd "$playbook_dir"
    log_info "Running Ansible playbook (host key checking disabled): $playbook"
    if ! ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook "$playbook"; then
        log_error "Ansible playbook failed. Exiting."
        safe_popd
        exit 2
    fi
    safe_popd
}

run_terraform_command() {
    local subcommand="$1"
    log_info "Changing directory to $TERRAFORM_DIR"
    safe_pushd "$TERRAFORM_DIR"
    log_info "Initializing Terraform"
    if ! terraform init; then
        log_error "Terraform init failed. Exiting."
        safe_popd
        exit 3
    fi

    case "$subcommand" in
        validate)
            log_info "Validating Terraform configuration"
            terraform validate
            ;;
        plan)
            log_info "Planning Terraform changes"
            terraform plan
            ;;
        apply)
            log_info "Applying Terraform plan"
            terraform apply -auto-approve
            ;;
        destroy)
            log_info "Destroying Terraform-managed infrastructure"
            terraform destroy -auto-approve
            ;;
        *)
            echo "$USAGE"
            safe_popd
            exit 1
            ;;
    esac
    safe_popd
}

# === MAIN ===
main() {
    if [[ $# -lt 1 ]]; then
        echo "$USAGE"
        exit 1
    fi

    validate_binaries
    log_info "Loading config from $CONFIG_FILE"
    load_config_yml "$CONFIG_FILE"

    case "$1" in
        deploy)
            log_header "Starting Proxmox Automated Landscape Install"
            run_ansible_playbook "$ANSIBLE_DEPLOY_DIR" "$ANSIBLE_DEPLOY_PLAYBOOK"
            run_terraform_command apply
            ;;
        manage)
            log_header "Starting Proxmox Automated Landscape Management"
            run_terraform_command apply
            ;;
        destroy)
            log_header "Starting Proxmox Automated Landscape Destroy"
            run_terraform_command destroy
            ;;
        terraform)
            case "${2:-}" in
                validate|plan|apply|destroy)
                    run_terraform_command "$2"
                    ;;
                *)
                    echo "$USAGE"
                    exit 1
                    ;;
            esac
            ;;
        ansible)
            case "${2:-}" in
                deploy)
                    run_ansible_playbook "$ANSIBLE_DEPLOY_DIR" "$ANSIBLE_DEPLOY_PLAYBOOK"
                    ;;
                configure)
                    run_ansible_playbook_nohostkey "$ANSIBLE_CONFIGURE_DIR" "$ANSIBLE_CONFIGURE_PLAYBOOK"
                    ;;
                *)
                    echo "$USAGE"
                    exit 1
                    ;;
            esac
            ;;
        *)
            echo "Unknown command: $1"
            echo "$USAGE"
            exit 1
            ;;
    esac

    log_header "Setup complete! Check Proxmox Web UI and SSH access to your VM."
    log_info "Date: $CURRENT_DATE"
    log_info "Script: $SCRIPT_NAME"
}

main "$@"
