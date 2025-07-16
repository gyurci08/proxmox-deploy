variable "proxmox_node" {
  description = "Proxmox node name"
  type        = string
}

variable "proxmox_host" {
  description = "Proxmox API host"
  type        = string
}

variable "proxmox_ssh_port" {
  description = "Proxmox SSH port"
  type        = string
}

variable "proxmox_user" {
  description = "Proxmox username"
  type        = string
}

variable "proxmox_password" {
  description = "Proxmox password"
  type        = string
  sensitive   = true
}

variable "proxmox_api_id" {
  description = "Proxmox API ID"
  type        = string
}

variable "proxmox_api_key" {
  description = "Proxmox API key"
  type        = string
  sensitive   = true
}

variable "proxmox_ssh_key" {
  description = "Path to Proxmox SSH key"
  type        = string
}

variable "cloud_init_user" {
  description = "Cloud-init user"
  type        = string
}

variable "cloud_init_password" {
  description = "Cloud-init password"
  type        = string
  sensitive   = true
}

variable "cloud_init_searchdomain" {
  description = "Cloud-init searchdomain"
  type        = string
}

variable "cloud_init_gateway" {
  description = "Cloud-init gateway"
  type        = string
}

variable "cloud_init_nameserver" {
  description = "Cloud-init nameserver"
  type        = string
}

variable "cloud_init_ssh_public_keys" {
  description = "SSH public keys"
  type        = string
}

variable "salt_master_hostname" {
  description = "The hostname of the SALT master"
  type        = string
}

variable "salt_master_ip" {
  description = "The ip address of the SALT master"
  type        = string
}