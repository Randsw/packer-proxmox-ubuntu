packer {
    required_plugins {
        proxmox = {
            version = " >= 1.1.0"
            source  = "github.com/hashicorp/proxmox"
        }
    }
}

variable "proxmox_api_url" {
    type = string
    default = env("PROXMOX_API_URL")
}

variable "proxmox_api_token_id" {
    type = string
    default = env("PROXMOX_API_TOKEN_ID")
}

variable "proxmox_api_token_secret" {
    type = string
    sensitive = true
    default = env("PROXMOX_API_TOKEN_SECRET")
}

variable "vm_id" {
    type = string
    default = "999"
}

# Resource Definiation for the VM Template
source "proxmox-iso" "ubuntu-server-jammy" {
    # Proxmox Connection Settings
    proxmox_url = "${var.proxmox_api_url}"
    username = "${var.proxmox_api_token_id}"
    token = "${var.proxmox_api_token_secret}"
    # (Optional) Skip TLS Verification
    insecure_skip_tls_verify = true
    
    # VM General Settings
    node = "pve"
    vm_id = "${var.vm_id}"
    vm_name = "ml-ubuntu-server-jammy"
    template_description = "ML Ubuntu Server jammy Image"

    # VM OS Settings
    # (Option 1) Local ISO File
    iso_file = "local:iso/ubuntu-22.04.1-live-server-amd64.iso"
    #iso_file = "local:iso/jammy-server-cloudimg-amd64.img"
    # - or -
    # (Option 2) Download ISO
    #iso_url = "https://releases.ubuntu.com/22.04/ubuntu-22.04.1-live-server-amd64.iso"
    #iso_checksum = "10f19c5b2b8d6db711582e0e27f5116296c34fe4b313ba45f9b201a5007056cb"
    #iso_storage_pool = "local"
    unmount_iso = true

    # VM System Settings
    qemu_agent = true

    # VM Hard Disk Settings
    scsi_controller = "virtio-scsi-pci"

    disks {
        disk_size = "20G"
        storage_pool = "local-zfs"
        storage_pool_type = "zfspool"
        type = "scsi"
    }

    # VM CPU Settings
    cores = "2"
    
    # VM Memory Settings
    memory = "4096" 

    # VM Network Settings
    network_adapters {
        model = "virtio"
        bridge = "vmbr0"
        firewall = "false"
    } 

    # VM Cloud-Init Settings
    cloud_init = true
    cloud_init_storage_pool = "local-zfs"

    boot_key_interval = "50ms"
    boot_wait = "6s"

    # PACKER Boot Commands from HTTP server
    # boot_command = [
    #     "c",
    #     "linux /casper/vmlinuz --- autoinstall ds='nocloud-net;s=http://{{ .HTTPIP }}:{{ .HTTPPort }}/' ",
    #     "<enter><wait>",
    #     "initrd /casper/initrd<enter><wait>",
    #     "boot<enter>"
    # ]
    # http_directory = "http" 
    # # (Optional) Bind IP Address and Port
    # # http_bind_address = "0.0.0.0"
    # http_port_min = 8802
    # http_port_max = 8802
    # http_interface = "wlp2s0"
    # vm_interface = "vmbr0"


    # PACKER Boot Commands from CD-ROM
    boot_command = [
        "c",
        "linux /casper/vmlinuz --- autoinstall ",
        "<enter><wait>",
        "initrd /casper/initrd<enter><wait>",
        "boot<enter>"
    ]
    
    additional_iso_files {
    cd_files = [
        "./http/meta-data",
        "./http/user-data"
    ]
    cd_label = "cidata"
    iso_storage_pool = "local"
    unmount = true
    }

    ssh_username = "ubuntu"

    # (Option 1) Add your Password here
    ssh_password = "ubuntu"
    # - or -
    # (Option 2) Add your Private SSH KEY file here
    # ssh_private_key_file = "~/.ssh/id_rsa"

    # Raise the timeout, when installation takes longer
    ssh_timeout = "60m"
}

# Build Definition to create the VM Template
build {

    name = "ubuntu-server-jammy"
    sources = ["source.proxmox-iso.ubuntu-server-jammy"]

    # Provisioning the VM Template for Cloud-Init Integration in Proxmox #1
    provisioner "shell" {
        inline = [
            "while [ ! -f /var/lib/cloud/instance/boot-finished ]; do echo 'Waiting for cloud-init...'; sleep 1; done",
            "sudo cloud-init clean",
            "sudo rm /etc/ssh/ssh_host_*",
            "sudo truncate -s 0 /etc/machine-id",
            "sudo sync"
        ]
    }
    
    # Provisioning the VM Template for Cloud-Init Integration in Proxmox #2
    provisioner "file" {
        source = "files/99-pve.cfg"
        destination = "/tmp/99-pve.cfg"
    }

    # Provisioning the VM Template for Cloud-Init Integration in Proxmox #3
    provisioner "shell" {
        inline = [ "sudo cp /tmp/99-pve.cfg /etc/cloud/cloud.cfg.d/99-pve.cfg" ]
    }

    # Provisioning the VM Template with Docker Installation #4
    provisioner "shell" {
        inline = [
            "sudo apt-get install -y ca-certificates curl gnupg lsb-release",
            "curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg",
            "echo \"deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable\" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null",
            "sudo apt-get -y update",
            "sudo apt-get install -y docker-ce docker-ce-cli containerd.io",
            "sudo apt-get install docker-compose-plugin",
            "sudo usermod -aG docker $USER"
        ]
    }

    # Delete CD-ROM with ISO https://github.com/hashicorp/packer-plugin-proxmox/issues/83
    post-processor "shell-local" {
        command = "curl -k -X POST -H 'Authorization: PVEAPIToken=${var.proxmox_api_token_id}=${var.proxmox_api_token_secret}' --data-urlencode delete=ide2 ${var.proxmox_api_url}/nodes/pve/qemu/${var.vm_id}/config"
    }
    
}