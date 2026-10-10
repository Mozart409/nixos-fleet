terraform {
  backend "pg" {}

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.91.0"
    }
  }
}
# Set the variable value in *.tfvars file
variable "endpoint" {
  sensitive = false
}
variable "username" {
  sensitive = true
}

variable "password" {
  sensitive = true
}
provider "proxmox" {
  # Configuration options
  endpoint = var.endpoint
  username = var.username
  password = var.password
  # Proxmox's own web cert on :8006 is self-signed; true regardless of
  # whether endpoint is the LAN IP or the Tailscale MagicDNS name.
  insecure = true
  ssh {
    agent = true
  }
}


# Debian 12 Cloud Image Download (raw format for ZFS compatibility)
resource "proxmox_virtual_environment_download_file" "debian_cloud_image" {
  content_type = "iso"
  datastore_id = "local"
  node_name    = "pve-gigabyte"

  url = "https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-generic-amd64.raw"

  file_name          = "debian-12-generic-amd64.img"
  overwrite          = false
  checksum           = "b5666c8d22e6422a641c08c897617f0b31c413d309711ad62203887501fb7d62eaf4763f54874ff00f7e32a5588fe532ec0b114a4a265aaa1c78e94b12d2e72e"
  checksum_algorithm = "sha512"
}

# Fedora 44 Cloud Base (Generic) Image Download
resource "proxmox_virtual_environment_download_file" "fedora_cloud_image" {
  content_type = "iso"
  datastore_id = "local"
  node_name    = "pve-gigabyte"

  url = "https://download.fedoraproject.org/pub/fedora/linux/releases/44/Cloud/x86_64/images/Fedora-Cloud-Base-Generic-44-1.7.x86_64.qcow2"

  file_name          = "fedora-44-generic-amd64.img"
  overwrite          = false
  checksum           = "28680fe5b371a5a82ebf43a31926e086a168e59949d03969c5093e7071f90b7f"
  checksum_algorithm = "sha256"
}


# PostgreSQL Database VM
resource "proxmox_virtual_environment_vm" "database_vm" {
  name        = "database"
  description = "Database - Debian base for NixOS installation via nixos-anywhere"
  tags        = ["terraform", "debian", "nixos-target", "database"]

  node_name = "pve-gigabyte"
  vm_id     = 4323

  bios = "seabios"

  keyboard_layout = "de"

  cpu {
    cores = 2
    type  = "host"
  }

  memory {
    dedicated = 1536
    floating  = 768
  }

  disk {
    datastore_id = "zfs_pool"
    file_id      = proxmox_virtual_environment_download_file.debian_cloud_image.id
    interface    = "scsi0"
    size         = 64
  }

  network_device {
    bridge = "vmbr0"
  }

  operating_system {
    type = "l26"
  }

  initialization {
    datastore_id = "local-lvm"

    ip_config {
      ipv4 {
        address = "dhcp"
      }
    }

    user_account {
      username = "amadeus"
      keys     = ["ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHv1USrKf6yIjg8dZolm37xGysGfj18ol1KUKqsVuQHa amadeus@wotan"]
    }
  }

  serial_device {}

  # Enable QEMU Guest Agent
  agent {
    enabled = true
    timeout = "60s"
  }

  started = true

  startup {
    order    = 1
    up_delay = 30
  }
}

# OpenTelemetry Collector VM
resource "proxmox_virtual_environment_vm" "otel_vm" {
  name        = "otel"
  description = "OpenTelemetry Collector - Debian base for NixOS installation via nixos-anywhere"
  tags        = ["terraform", "debian", "nixos-target", "monitoring"]

  node_name = "pve-gigabyte"
  vm_id     = 4325

  bios = "seabios"

  keyboard_layout = "de"

  cpu {
    cores = 2
    type  = "host"
  }

  memory {
    dedicated = 4096
    floating  = 4096
  }

  disk {
    datastore_id = "zfs_pool"
    file_id      = proxmox_virtual_environment_download_file.debian_cloud_image.id
    interface    = "scsi0"
    size         = 32
  }

  network_device {
    bridge = "vmbr0"
  }

  operating_system {
    type = "l26"
  }

  initialization {
    datastore_id = "local-lvm"

    ip_config {
      ipv4 {
        address = "dhcp"
      }
    }

    user_account {
      username = "amadeus"
      keys     = ["ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHv1USrKf6yIjg8dZolm37xGysGfj18ol1KUKqsVuQHa amadeus@wotan"]
    }
  }

  serial_device {}

  # Enable QEMU Guest Agent
  agent {
    enabled = true
    timeout = "60s"
  }

  started = true

  startup {
    order    = 2
    up_delay = 15
  }
}

# DNS Server VM (Unbound)
resource "proxmox_virtual_environment_vm" "dns_vm" {
  name        = "dns"
  description = "DNS Server (Unbound) - Debian base for NixOS installation via nixos-anywhere"
  tags        = ["terraform", "debian", "nixos-target", "dns"]

  node_name = "pve-gigabyte"
  vm_id     = 4326

  bios = "seabios"

  keyboard_layout = "de"

  cpu {
    cores = 2
    type  = "host"
  }

  memory {
    dedicated = 1536
    floating  = 1536
  }

  # ssd_pool: this guest is the resolver every host and every colmena deploy
  # depends on, and zfs_pool is a 2-HDD mirror (~78 IOPS) that stalls every guest
  # together. 32 GB leaves ~27 G of root after the XFS layout's 1 G /boot + 4 G
  # swap. `file_format = "raw"` is required -- ssd_pool is a zfspool and stores
  # only raw volumes; without it the import fails as qcow2. See
  # todo/dns-cache-ssd-xfs-migration.md.
  # BLANK disk -- deliberately no file_id. Importing a cloud image onto this
  # zfspool kept failing with "timeout: no zvol device link for
  # 'vm-4326-disk-0' found after 10 sec", leaving a VM with no bootable disk
  # that just hangs at SeaBIOS. The pool was idle at the time, so it is the
  # import path itself, not contention. A blank volume is a plain `zfs create
  # -V` and avoids it entirely; the installer comes from the CD-ROM below.
  disk {
    datastore_id = "ssd_pool"
    interface    = "scsi0"
    size         = 32
    discard      = "on"
    file_format  = "raw"
  }

  # The repo's own installer ISO (`just iso-build`, hosts/iso/configuration.nix).
  # It already carries the amadeus SSH key via modules/common.nix, so no
  # cloud-init datasource is needed to get in -- and because it boots straight
  # into a NixOS installer there is nothing to kexec, which sidesteps both the
  # ~1.5 GB kexec RAM floor and the need for scratch space on the target.
  # Deploy with:  just deploy dns <dhcp-ip> --phases disko,install,reboot
  #
  # The name is whatever `just iso-build` produced and you uploaded to the
  # `local` datastore -- it carries the nixpkgs revision, so it changes every
  # time the ISO is rebuilt after a flake update. Rebuilt the ISO? Re-upload and
  # update this string, or the next apply fails on a missing volume.
  # ide0, not ide2: the initialization block below claims ide2 for its
  # cloud-init drive.
  cdrom {
    file_id   = "local:iso/nixos-homelab-26.11.20260907.dc5d91f-x86_64-linux.iso"
    interface = "ide0"
  }

  # Disk FIRST, CD second. A freshly created zvol is all zeroes with no MBR
  # signature, so SeaBIOS skips it and falls through to the ISO -- but once
  # nixos-anywhere has installed, the disk boots and the still-attached ISO is
  # ignored. Ordering it the other way round would reboot into the installer
  # forever unless you remembered to detach the CD by hand.
  boot_order = ["scsi0", "ide0"]

  network_device {
    bridge = "vmbr0"
  }

  operating_system {
    type = "l26"
  }

  initialization {
    datastore_id = "local-lvm"

    # Static, not dhcp: this guest is the resolver, and after a recreate the
    # Debian phase would otherwise come up on a lease you have to go hunting
    # for before nixos-anywhere can target it. The NixOS config pins the same
    # address (hosts/dns/configuration.nix, networking.interfaces.ens18), so
    # this only governs the pre-install image -- but it means
    # `just deploy dns 192.168.2.145` works immediately after `tofu apply`.
    ip_config {
      ipv4 {
        address = "192.168.2.145/24"
        gateway = "192.168.2.1"
      }
    }

    user_account {
      username = "amadeus"
      keys     = ["ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHv1USrKf6yIjg8dZolm37xGysGfj18ol1KUKqsVuQHa amadeus@wotan"]
    }
  }

  serial_device {}

  # Enable QEMU Guest Agent
  agent {
    enabled = true
    timeout = "60s"
  }

  started = true

  startup {
    order    = 2
    up_delay = 15
  }
}

# UniFi Network Controller VM
resource "proxmox_virtual_environment_vm" "unifi_vm" {
  name        = "unifi"
  description = "UniFi Network Controller - Debian base for NixOS installation via nixos-anywhere"
  tags        = ["terraform", "debian", "nixos-target", "unifi"]

  node_name = "pve-gigabyte"
  vm_id     = 4327

  bios = "seabios"

  keyboard_layout = "de"

  cpu {
    cores = 4
    type  = "host"
  }

  memory {
    dedicated = 2560
    floating  = 1280
  }

  disk {
    datastore_id = "zfs_pool"
    file_id      = proxmox_virtual_environment_download_file.debian_cloud_image.id
    interface    = "scsi0"
    size         = 32
  }

  network_device {
    bridge = "vmbr0"
  }

  operating_system {
    type = "l26"
  }

  initialization {
    datastore_id = "local-lvm"

    ip_config {
      ipv4 {
        address = "dhcp"
      }
    }

    user_account {
      username = "amadeus"
      keys     = ["ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHv1USrKf6yIjg8dZolm37xGysGfj18ol1KUKqsVuQHa amadeus@wotan"]
    }
  }

  serial_device {}

  # Enable QEMU Guest Agent
  agent {
    enabled = true
    timeout = "60s"
  }

  started = true

  startup {
    order    = 2
    up_delay = 15
  }
}

# Container VM
resource "proxmox_virtual_environment_vm" "containers_vm" {
  name        = "containers"
  description = "Containers"
  tags        = ["terraform", "debian", "nixos-target", "oci"]

  node_name = "pve-gigabyte"
  vm_id     = 4328

  bios = "seabios"

  keyboard_layout = "de"

  cpu {
    cores = 4
    type  = "host"
  }

  memory {
    dedicated = 3584
    floating  = 1792
  }

  disk {
    datastore_id = "zfs_pool"
    file_id      = proxmox_virtual_environment_download_file.debian_cloud_image.id
    interface    = "scsi0"
    size         = 32
  }

  network_device {
    bridge = "vmbr0"
  }

  operating_system {
    type = "l26"
  }

  initialization {
    datastore_id = "local-lvm"

    ip_config {
      ipv4 {
        address = "dhcp"
      }
    }

    user_account {
      username = "amadeus"
      keys     = ["ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHv1USrKf6yIjg8dZolm37xGysGfj18ol1KUKqsVuQHa amadeus@wotan"]
    }
  }

  serial_device {}

  # Enable QEMU Guest Agent
  agent {
    enabled = true
    timeout = "60s"
  }

  started = true

  startup {
    order    = 2
    up_delay = 15
  }
}
# MCP VM
resource "proxmox_virtual_environment_vm" "mcp_vm" {
  name        = "mcp"
  description = "mcp vm"
  tags        = ["terraform", "debian", "nixos-target", "oci"]

  node_name = "pve-gigabyte"
  vm_id     = 4333

  bios = "seabios"

  keyboard_layout = "de"

  cpu {
    cores = 4
    type  = "host"
  }

  memory {
    dedicated = 1536
    floating  = 768
  }

  disk {
    datastore_id = "zfs_pool"
    file_id      = proxmox_virtual_environment_download_file.debian_cloud_image.id
    interface    = "scsi0"
    size         = 32
  }

  network_device {
    bridge = "vmbr0"
  }

  operating_system {
    type = "l26"
  }

  initialization {
    datastore_id = "local-lvm"

    ip_config {
      ipv4 {
        address = "dhcp"
      }
    }

    user_account {
      username = "amadeus"
      keys     = ["ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHv1USrKf6yIjg8dZolm37xGysGfj18ol1KUKqsVuQHa amadeus@wotan"]
    }
  }

  serial_device {}

  # Enable QEMU Guest Agent
  agent {
    enabled = true
    timeout = "60s"
  }

  started = true

  startup {
    order    = 2
    up_delay = 15
  }
}


# Certificate Authority (step-ca) VM
resource "proxmox_virtual_environment_vm" "ca_vm" {
  name        = "ca"
  description = "Certificate Authority (step-ca) - Debian base for NixOS installation via nixos-anywhere"
  tags        = ["terraform", "debian", "nixos-target", "security", "ca"]

  node_name = "pve-gigabyte"
  vm_id     = 4337

  bios = "seabios"

  keyboard_layout = "de"

  cpu {
    cores = 2
    type  = "host"
  }

  memory {
    dedicated = 2048
    floating  = 2048
  }

  # ssd_pool, same reasoning as dns_vm above -- and here it is measured, not
  # assumed. On 2026-09-09 this guest needed ~500 ms for a single 4 KiB O_DSYNC
  # write (20 of them took 10.04 s, i.e. ~2 IOPS) while /proc/pressure/io sat at
  # full avg60=67 with CPU pressure at 0.00. step-ca's badgerv2 store writes and
  # deletes a record per ACME anti-replay nonce, so four concurrent issuances on
  # that disk turned into a badNonce storm that Caddy could not retry its way
  # out of. The CA was never CPU- or RAM-starved; it was starved on the spindles.
  #
  # 32 GB (was 20) because the old root ran at 89 % -- the same figure dns sat at
  # before btrfs wedged. Blank disk + `file_format = "raw"`: see the dns_vm block
  # for why a cloud-image import onto a zfspool cannot work.
  disk {
    datastore_id = "ssd_pool"
    interface    = "scsi0"
    size         = 32
    discard      = "on"
    file_format  = "raw"
  }

  # Same installer ISO as dns_vm -- rebuild it and both file_id strings change.
  #
  # Do NOT add `enabled` here: bpg 0.91.0 deprecates it ("no longer used"), and
  # `file_id` alone is what attaches the drive. The `enabled = false` that shows
  # up in a plan diff is vestigial state, not a disabled drive. Set `file_id` to
  # `none` if you ever want the drive empty.
  cdrom {
    file_id   = "local:iso/nixos-homelab-26.11.20260907.dc5d91f-x86_64-linux.iso"
    interface = "ide0"
  }

  # Disk first, CD second -- see dns_vm.
  boot_order = ["scsi0", "ide0"]

  network_device {
    bridge = "vmbr0"
  }

  operating_system {
    type = "l26"
  }

  initialization {
    datastore_id = "local-lvm"

    # The NixOS config pins the same address
    # (hosts/ca/configuration.nix, networking.interfaces.ens18), so this governs
    # only the pre-install image -- but it means the installer comes up on a
    # known address instead of a lease you have to hunt for.
    ip_config {
      ipv4 {
        address = "192.168.2.160/24"
        gateway = "192.168.2.1"
      }
    }

    user_account {
      username = "amadeus"
      keys     = ["ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHv1USrKf6yIjg8dZolm37xGysGfj18ol1KUKqsVuQHa amadeus@wotan"]
    }
  }

  serial_device {}

  # Enable QEMU Guest Agent
  agent {
    enabled = true
    timeout = "60s"
  }

  started = true

  startup {
    order    = 2
    up_delay = 15
  }
}

# Forgejo VM (Git forge - uses external Postgres on database host)
resource "proxmox_virtual_environment_vm" "forgejo_vm" {
  name        = "forgejo"
  description = "Forgejo Git Forge - Debian base for NixOS installation via nixos-anywhere"
  tags        = ["terraform", "debian", "nixos-target", "forgejo", "git"]

  node_name = "pve-gigabyte"
  vm_id     = 4341

  bios = "seabios"

  keyboard_layout = "de"

  cpu {
    cores = 2
    type  = "host"
  }

  # Pinned floating = dedicated: ballooning dragged this guest to its 768 MiB
  # floor (MemTotal swung 698-1466 MiB over 2026-08-20..08-30) as pvestatd
  # chased the host past its ~80% reclaim threshold. At 698 MiB the guest
  # swapped onto zfs_pool (two HDDs, ~78 IOPS shared), I/O pressure hit
  # full=47%, page loads took 4-9s and systemctl/journalctl wedged. Same fix
  # as harbor_vm and woodpecker_vm above. Root cause is host oversubscription:
  # todo/pve-gigabyte-memory-oversubscription.md.
  memory {
    dedicated = 1536
    floating  = 1536
  }

  disk {
    datastore_id = "zfs_pool"
    file_id      = proxmox_virtual_environment_download_file.debian_cloud_image.id
    interface    = "scsi0"
    size         = 40
  }

  network_device {
    bridge = "vmbr0"
  }

  operating_system {
    type = "l26"
  }

  initialization {
    datastore_id = "local-lvm"

    ip_config {
      ipv4 {
        address = "dhcp"
      }
    }

    user_account {
      username = "amadeus"
      keys     = ["ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHv1USrKf6yIjg8dZolm37xGysGfj18ol1KUKqsVuQHa amadeus@wotan"]
    }
  }

  serial_device {}

  agent {
    enabled = true
    timeout = "60s"
  }

  started = true

  on_boot = true
}

# Jellyfin Media Server VM
resource "proxmox_virtual_environment_vm" "jellyfin_vm" {
  name        = "jellyfin"
  description = "Jellyfin Media Server - Debian base for NixOS installation via nixos-anywhere"
  tags        = ["terraform", "debian", "nixos-target", "media", "jellyfin"]

  node_name = "pve-gigabyte"
  vm_id     = 4344

  bios = "seabios"

  keyboard_layout = "de"

  cpu {
    cores = 4
    type  = "host"
  }

  memory {
    dedicated = 4096
    floating  = 4096
  }

  # OS disk (scsi0 -> /dev/sda): btrfs root via disko-jellyfin.nix
  disk {
    datastore_id = "zfs_pool"
    file_id      = proxmox_virtual_environment_download_file.debian_cloud_image.id
    interface    = "scsi0"
    size         = 32
  }

  # Media storage disk (scsi1 -> /dev/sdb): ZFS "mediapool" via disko-jellyfin.nix
  disk {
    datastore_id = "zfs_pool"
    interface    = "scsi1"
    size         = 768
    file_format  = "raw"
  }

  network_device {
    bridge = "vmbr0"
  }

  operating_system {
    type = "l26"
  }

  initialization {
    datastore_id = "local-lvm"

    ip_config {
      ipv4 {
        address = "192.168.2.180/24"
        gateway = "192.168.2.1"
      }
    }

    user_account {
      username = "amadeus"
      keys     = ["ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHv1USrKf6yIjg8dZolm37xGysGfj18ol1KUKqsVuQHa amadeus@wotan"]
    }
  }

  serial_device {}

  # Enable QEMU Guest Agent
  agent {
    enabled = true
    timeout = "60s"
  }

  started = true

  startup {
    order    = 2
    up_delay = 15
  }
}



# Agents VM: the agent platform (knowledge-base/projects/agent-platform).
# Multica daemons per trust zone, each zone a microVM inside this guest.
resource "proxmox_virtual_environment_vm" "agents_vm" {
  name        = "agents"
  description = "Agent platform - NixOS host for the Multica daemons and their microVM zones"
  tags        = ["terraform", "nixos", "nixos-target", "ai", "agents"]

  node_name = "pve-gigabyte"
  vm_id     = 4350

  bios = "seabios"

  keyboard_layout = "de"

  # `host` is required, not a tuning choice: the zones are microVMs, and nested
  # KVM only works when the guest sees the real CPU (kvm_amd nested=1 on the
  # PVE host, checked 2026-10-05). 6 cores for two zones that each realise
  # devShells and run agent CLIs; `development` (4 cores) hit load 12.9 with
  # four concurrent cold evals.
  cpu {
    cores = 6
    type  = "host"
  }

  # Pinned, no ballooning (same reasoning as the hermes VM this replaces): the
  # microVMs reserve their RAM up front, and a balloon reclaiming it would
  # starve them. 16 GB = heimdahl zone ~8 + assistant ~3 + host and its Nix
  # store. Fits in the ~20 GB that retiring development (12) and hermes (8)
  # freed on this oversubscribed node (todo/pve-gigabyte-memory-oversubscription.md).
  memory {
    dedicated = 16384
    floating  = 16384
  }

  # ssd_pool + XFS (modules/disko-xfs.nix), blank disk + raw, like dns/ca: a
  # cloud-image import onto a zfspool cannot work (see dns_vm). 128 GB holds
  # the Nix store, the microVM volumes and the per-task git worktrees under
  # /srv/work. `discard = "on"` lets disko-xfs's weekly fstrim return blocks.
  disk {
    datastore_id = "ssd_pool"
    interface    = "scsi0"
    size         = 128
    discard      = "on"
    file_format  = "raw"
  }

  # Same installer ISO as dns_vm and ca_vm -- rebuild it and every file_id
  # string changes. Do NOT add `enabled` (see ca_vm).
  cdrom {
    file_id   = "local:iso/nixos-homelab-26.11.20260907.dc5d91f-x86_64-linux.iso"
    interface = "ide0"
  }

  # Disk first, CD second -- see dns_vm.
  boot_order = ["scsi0", "ide0"]

  network_device {
    bridge = "vmbr0"
  }

  operating_system {
    type = "l26"
  }

  initialization {
    datastore_id = "local-lvm"

    # Same address as hosts/agents/configuration.nix pins, so the installer
    # comes up where nixos-anywhere expects it.
    ip_config {
      ipv4 {
        address = "192.168.2.190/24"
        gateway = "192.168.2.1"
      }
    }

    user_account {
      username = "amadeus"
      keys     = ["ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHv1USrKf6yIjg8dZolm37xGysGfj18ol1KUKqsVuQHa amadeus@wotan"]
    }
  }

  serial_device {}

  agent {
    enabled = true
    timeout = "60s"
  }

  # Boots onto the installer ISO; nixos-anywhere then installs over SSH
  # (the `deploy` recipe, with agents and 192.168.2.190).
  started = true

  on_boot = true
}


output "vm_ipv4_addresses" {
  description = "Primary IPv4 addresses per VM"
  value = {
    database  = proxmox_virtual_environment_vm.database_vm.ipv4_addresses
    otel      = proxmox_virtual_environment_vm.otel_vm.ipv4_addresses
    dns       = proxmox_virtual_environment_vm.dns_vm.ipv4_addresses
    unifi     = proxmox_virtual_environment_vm.unifi_vm.ipv4_addresses
    container = proxmox_virtual_environment_vm.containers_vm.ipv4_addresses
    mcp       = proxmox_virtual_environment_vm.mcp_vm.ipv4_addresses
    ca        = proxmox_virtual_environment_vm.ca_vm.ipv4_addresses
    forgejo   = proxmox_virtual_environment_vm.forgejo_vm.ipv4_addresses
    jellyfin  = proxmox_virtual_environment_vm.jellyfin_vm.ipv4_addresses
    agents    = proxmox_virtual_environment_vm.agents_vm.ipv4_addresses
  }
}

