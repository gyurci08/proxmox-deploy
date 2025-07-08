resource "proxmox_vm_qemu" "test-1" {
  name        = "test-1"
  target_node = "jgy-dev-proxmox"
  clone       = "template-suse-Leap-15.6"
  cores       = 2
  memory      = 2048
  os_type     = "Linux"

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
