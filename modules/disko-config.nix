{lib, ...}: {
  disko.devices = {
    disk = {
      main = {
        type = "disk";
        device = lib.mkDefault "/dev/sda";
        content = {
          type = "gpt";
          partitions = {
            # BIOS boot partition for GRUB
            bios = {
              size = "1M";
              type = "EF02";
            };
            boot = {
              size = "1G";
              label = "boot";
              content = {
                type = "filesystem";
                format = "ext4";
                mountpoint = "/boot";
                # Same slow-zvol case as "/" below: the device wait defaults to 90 s and drops the boot into emergency mode.
                mountOptions = ["defaults" "x-systemd.device-timeout=5min" "x-systemd.mount-timeout=5min"];
              };
            };
            root = {
              size = "100%";
              label = "nixos";
              content = {
                type = "btrfs";
                extraArgs = ["-f" "-L" "nixos"];
                subvolumes = {
                  "/root" = {
                    mountpoint = "/";
                    # A slow zvol (disk reset, PBS backup) must not fail the boot at systemd's 90 s default.
                    mountOptions = ["compress=zstd" "noatime" "x-systemd.mount-timeout=5min"];
                  };
                  "/home" = {
                    mountpoint = "/home";
                    mountOptions = ["compress=zstd" "noatime"];
                  };
                  "/nix" = {
                    mountpoint = "/nix";
                    mountOptions = ["compress=zstd" "noatime"];
                  };
                  "/var" = {
                    mountpoint = "/var";
                    mountOptions = ["compress=zstd" "noatime"];
                  };
                  "/swap" = {
                    mountpoint = "/.swapvol";
                    swap.swapfile.size = "4G";
                  };
                };
              };
            };
          };
        };
      };
    };
  };

  # GRUB bootloader configuration
  # Disko automatically configures GRUB based on the disk layout
  # Just ensure GRUB is enabled
  boot.loader.grub = {
    enable = true;
    efiSupport = false;
    forceInstall = true;
    fsIdentifier = "uuid";
  };

  # Ensure necessary modules are available in initrd
  boot.initrd.availableKernelModules = [
    "ahci"
    "xhci_pci"
    "virtio_pci"
    "virtio_scsi"
    "sd_mod"
    "sr_mod"
  ];

  # Enable support for btrfs in initrd
  boot.initrd.supportedFilesystems = ["btrfs"];
}
