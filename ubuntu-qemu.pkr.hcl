packer {
  required_plugins {
    qemu = {
      version = " >= 1.0.4"
      source  = "github.com/hashicorp/qemu"
    }
  }
}

variable "vm_template_name" {
  type    = string
  default = "ml-ubuntu-22.04"
}

variable "ubuntu_iso_file" {
  type    = string
  default = "ubuntu-22.04.1-live-server-amd64.iso"
}

variable "user_data_location" {
  type    = string
  default = "user-data"
}

source "qemu" "test_ml_image" {

  # Boot Commands when Loading the ISO file with OVMF.fd file (Tianocore) / GrubV2
  boot_command = [
      "c",
      "linux /casper/vmlinuz --- autoinstall ds='nocloud-net;s=http://{{ .HTTPIP }}:{{ .HTTPPort }}/' ",
      "<enter><wait>",
      "initrd /casper/initrd<enter><wait>",
      "boot<enter>"
  ]
  boot_wait = "6s"

  http_directory = "http-qemu"
  iso_url   = "iso/${var.ubuntu_iso_file}"
  iso_checksum = "sha256:10f19c5b2b8d6db711582e0e27f5116296c34fe4b313ba45f9b201a5007056cb"
  memory = 4096

  ssh_password = "ubuntu"
  ssh_username = "ubuntu"
  ssh_timeout = "20m"
  shutdown_command = "echo 'ubuntu' | sudo -S shutdown -P now"

  headless = false # to see the process, In CI systems set to true
  accelerator = "kvm" # set to none if no kvm installed
  format = "qcow2"
  disk_interface = "virtio-scsi"
  disk_size = "30G"
  cpus = 2
  net_device       = "virtio-net"

  # qemuargs = [ # Depending on underlying machine the file may have different location
  #   ["-bios", "/usr/share/OVMF/OVMF_CODE.fd"]
  # ] 
  vm_name = "${var.vm_template_name}"
}

build {
  sources = [ "source.qemu.test_ml_image" ]
  provisioner "shell" {
    inline = [ "while [ ! -f /var/lib/cloud/instance/boot-finished ]; do echo 'Waiting for Cloud-Init...'; sleep 1; done",
            "sudo cloud-init clean",
            "sudo rm /etc/ssh/ssh_host_*",
            "sudo truncate -s 0 /etc/machine-id",
            "sudo sync" ]
  }

  ## Install python pip, install mathplotlib, numpy, ncdu, git, iostat
    provisioner "shell" {
    inline = [
        "sudo apt update -y",
        "sudo apt install python3-pip git sysstat ncdu -y",
        "pip install numpy matplotlib"
        ]
  }
}
