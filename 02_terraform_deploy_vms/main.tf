resource "proxmox_vm_qemu" "tst-1" {
  vmid              = 100
  name              = "tst-1"
  desc              = "A test VM."
  target_node       = "jgy-dev-proxmox"
  clone             = "template-suse-Leap-15.6"
  memory            = 1024
  agent             = 1
  automatic_reboot  = false # Enable reboot after terraform changes
  balloon           = 512
  bios              = "seabios"
  boot              = "order=virtio0"
  bootdisk          = "virtio0"
  machine           = "q35"
  os_type           = "Linux 5.x - 2.6 Kernel"
  protection        = false
  scsihw            = "virtio-scsi-pci"

  # Cloud-init settings
  ciuser            = "admin"
  cipassword        = var.vm_password
  searchdomain      = "internal.local"
  nameserver        = "10.0.1.254"
  sshkeys           = var.vm_ssh_public_key
  ipconfig0         = "ip=10.0.1.140/24,gw=10.0.1.254"

  cpu {
    cores   = 2
    sockets = 1
    type    = "host"
  }

  disk {
    discard  = true
    iothread = true
    size     = "10G"
    slot     = "virtio0"
    storage  = "local-lvm"
    type     = "disk"
  }

  disk {
    slot    = "ide0"
    storage = "local-lvm"
    type    = "cloudinit"
  }

  network {
    bridge   = "vmbr0"
    firewall = true
    id       = 0
    model    = "virtio"
  }  

  serial {
    id   = 0
    type = "socket"
    }
}
