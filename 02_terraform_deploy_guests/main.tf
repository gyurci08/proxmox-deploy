#####
### vm-master
#####
resource "proxmox_vm_qemu" "vm-master" {
  vmid              = 100
  name              = var.salt_master_hostname
  desc              = "The SALT master vm"
  target_node       = var.proxmox_node
  clone             = "template-suse-Leap-15.6"
  memory            = 1024
  agent             = 1
  automatic_reboot  = true
  balloon           = 1024
  bios              = "seabios"
  boot              = "order=virtio0"
  machine           = "q35"
  os_type           = "Linux 5.x - 2.6 Kernel"
  protection        = false
  scsihw            = "virtio-scsi-pci"
  onboot            = true

  # Cloud-init settings
  ciuser            = var.cloud_init_user
  cipassword        = var.cloud_init_password
  searchdomain      = var.cloud_init_searchdomain
  nameserver        = var.cloud_init_nameserver
  sshkeys           = var.cloud_init_ssh_public_keys
  ipconfig0         = "ip=${var.salt_master_ip}/24,gw=${var.cloud_init_gateway}"

  cpu {
    cores   = 2
    sockets = 1
    type    = "host"
  }

  disk {
    slot     = "ide0"
    storage  = "local-lvm"
    type     = "cloudinit"
    format   = "raw"
  }

  disk {
    slot     = "virtio0"
    storage  = "local-lvm"
    size     = "10G"
    type     = "disk"
    discard  = true
    iothread = true
    format   = "raw"
  }

  network {
    id       = 0
    bridge   = "vmbr0"
    firewall = true
    model    = "virtio"
  }  

  serial {
    id   = 0
    type = "socket"
  }
}

#####
### vm-test-1
#####
resource "proxmox_vm_qemu" "vm-test-1" {
  vmid              = 101
  name              = "vm-test-1"
  desc              = "A controlled SALT minion"
  target_node       = var.proxmox_node
  clone             = "template-suse-Leap-15.6"
  memory            = 1024
  agent             = 1
  automatic_reboot  = true
  balloon           = 1024
  bios              = "seabios"
  boot              = "order=virtio0"
  machine           = "q35"
  os_type           = "Linux 5.x - 2.6 Kernel"
  protection        = false
  scsihw            = "virtio-scsi-pci"
  onboot            = true

  # Cloud-init settings
  ciuser            = var.cloud_init_user
  cipassword        = var.cloud_init_password
  searchdomain      = var.cloud_init_searchdomain
  nameserver        = var.cloud_init_nameserver
  sshkeys           = var.cloud_init_ssh_public_keys
  ipconfig0         = "ip=10.0.1.141/24,gw=${var.cloud_init_gateway}"

  cpu {
    cores   = 2
    sockets = 1
    type    = "host"
  }

  disk {
    slot     = "ide0"
    storage  = "local-lvm"
    type     = "cloudinit"
    format   = "raw"
  }

  disk {
    slot     = "virtio0"
    storage  = "local-lvm"
    size     = "10G"
    type     = "disk"
    discard  = true
    iothread = true
    format   = "raw"
  }

  network {
    id       = 0
    bridge   = "vmbr0"
    firewall = true
    model    = "virtio"
  }  

  serial {
    id   = 0
    type = "socket"
  }
}
