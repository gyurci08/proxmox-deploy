resource "proxmox_vm_qemu" "tst-1" {
  name        = "tst-1"
  target_node = "jgy-dev-proxmox"
  clone       = "template-suse-Leap-15.6"
  os_type     = "cloud-init"
  memory      = 1024

  cpu {
    cores = 2
    type  = "host"
  }

  scsihw    = "virtio-scsi-pci"
  bootdisk  = "virtio0"

  disk {
    slot     = "virtio0"
    storage  = "local-lvm"
    size     = "10G"
    type     = "disk"
    iothread = true
    discard  = true
  }

  disk {
    slot    = "ide0"
    storage = "local-lvm"
    type    = "cloudinit"
  }

  network {
    id       = 0
    model    = "virtio"
    bridge   = "vmbr0"
    firewall = true
  }

  agent     = 1
  ipconfig0 = "ip=dhcp"
  sshkeys   = var.vm_ssh_public_key
}
