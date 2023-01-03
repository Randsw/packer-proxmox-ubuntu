# Build VM template for QEMU and Proxmox using Packer

## Build VM template for QEMU

`packer build ubuntu-qemu.pkr.hcl`

## Build VM template for Proxmox

`packer build -var-file=credential.pkr.hcl ubuntu-proxmox.pkr.hcl`
