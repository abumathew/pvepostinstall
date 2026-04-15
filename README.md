# Proxmox Bootstrap

Automates common post-install tasks for a new Proxmox VE host.

## What it does

- Runs post-install cleanup
- Applies CPU governor settings
- Configures NUT client
- Installs sensor tooling and GUI sensor mod
- Configures IOMMU/VFIO
- Enables powertop autotune

## Usage

```bash
cp .env.example .env
nano .env
make run
>>>>>>> c6bce1a (Initial commit - Proxmox bootstrap repo)
