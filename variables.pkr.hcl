# Packer Template to create an Ubuntu Server (Focal) on Proxmox

# Variable Definitions
# Variable Definitions
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