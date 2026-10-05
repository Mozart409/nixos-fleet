{
  config,
  lib,
  ...
}: let
  cfg = config.security.hardening;
in {
  options.security.hardening = {
    enable = lib.mkEnableOption "system security hardening";

    firewall = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable and configure firewall";
      };
      allowedTCPPorts = lib.mkOption {
        type = lib.types.listOf lib.types.port;
        default = [];
        description = "Additional TCP ports to allow";
      };
      allowedUDPPorts = lib.mkOption {
        type = lib.types.listOf lib.types.port;
        default = [];
        description = "Additional UDP ports to allow";
      };
    };

    ssh = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable SSH hardening";
      };
    };

    audit = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable audit logging (auditd)";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    # 1. Firewall configuration
    networking.firewall = lib.mkIf cfg.firewall.enable {
      enable = true;
      allowedTCPPorts = cfg.firewall.allowedTCPPorts;
      allowedUDPPorts = cfg.firewall.allowedUDPPorts;
      logReversePathDrops = true;
    };

    # 4. Kernel hardening
    boot.kernel.sysctl = {
      # Hide kernel pointers from unprivileged users
      "kernel.kptr_restrict" = 2;
      # Restrict ptrace to parent processes only
      "kernel.yama.ptrace_scope" = 1;
      # Enable reverse path filtering (anti-spoofing)
      "net.ipv4.conf.all.rp_filter" = 1;
      "net.ipv4.conf.default.rp_filter" = 1;
      # Disable ICMP redirects (prevents MITM)
      "net.ipv4.conf.all.accept_redirects" = 0;
      "net.ipv4.conf.default.accept_redirects" = 0;
      "net.ipv6.conf.all.accept_redirects" = 0;
      "net.ipv6.conf.default.accept_redirects" = 0;
      # Don't send ICMP redirects
      "net.ipv4.conf.all.send_redirects" = 0;
      "net.ipv4.conf.default.send_redirects" = 0;
      # Ignore ICMP echo requests to broadcast/multicast
      "net.ipv4.icmp_echo_ignore_broadcasts" = 1;
      # Protect against SYN flood attacks
      "net.ipv4.tcp_syncookies" = 1;
    };

    # Protect kernel image from modification
    security.protectKernelImage = true;

    # 5. SSH daemon hardening
    services.openssh = lib.mkIf cfg.ssh.enable {
      settings = {
        PasswordAuthentication = false;
        PermitRootLogin = "no";
        KbdInteractiveAuthentication = false;
        X11Forwarding = false;
        PermitEmptyPasswords = false;
        ChallengeResponseAuthentication = false;
        MaxAuthTries = 3;
        ClientAliveInterval = 300;
        ClientAliveCountMax = 2;
      };
    };

    # 6. Audit logging
    security.auditd.enable = cfg.audit.enable;
    security.audit = lib.mkIf cfg.audit.enable {
      enable = true;
      rules = [
        "-a exit,always -F arch=b64 -S execve"
      ];
    };

    # 7. Systemd-boot hardening
    boot.loader.systemd-boot.editor = false;
  };
}
