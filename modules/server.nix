# Fleet servers only: sshd and who may log in, metrics and log shipping,
# mosh, the CLI kit, passwordless sudo, Proxmox guest bits. Imported through
# modules/common.nix together with modules/base.nix. The desktop wotan must
# never import this (hosts/wotan/default.nix asserts that sshd stays off).
{
  config,
  lib,
  pkgs,
  ...
}: {
  imports = [
    ./nix-gc.nix
    # The homelab attic binary cache was retired 2026-09-09 with the cache VM
    # (iac/main.tf). It was imported here to spare hosts that evaluate the flake
    # locally from GitHub's 429 rate-limit on unauthenticated tarball downloads
    # — but comin, which made every host evaluate locally, is gone (6a387b2),
    # and colmena builds on the deploy host and pushes closures over SSH. Nothing
    # in the fleet evaluates the flake locally any more (the human-facing hosts
    # that did -- development, hermes, zeroclaw -- were all decommissioned on
    # 2026-10-06); if a host ever hits 429s, a GitHub token in
    # `nix.settings.access-tokens` is the direct fix, not a VM.
    # modules/attic-cache.nix is kept on disk, imported nowhere.
    # The journald -> Loki shipper. Imported here because every fleet host has
    # this module (through common.nix), so the shipper does not hang off an
    # unrelated module the way it hung off comin.nix (and briefly attic-push).
    ./fluent-bit.nix
    ./nixos-version-metrics.nix
    ./dns-client-cache.nix
  ];

  # Console font (the keymap is in base.nix)
  console.font = "Lat2-Terminus16";

  programs.zsh = {
    enable = true;
    enableCompletion = true;
    syntaxHighlighting.enable = true;
    autosuggestions.enable = true;
    histSize = 5000;
    histFile = "$HOME/.zsh_history";
    setOptions = [
      "HIST_IGNORE_SPACE"
      "EXTENDED_HISTORY"
      "HIST_IGNORE_DUPS"
      "HIST_SAVE_NO_DUPS"
      "SHARE_HISTORY"
      "HIST_EXPIRE_DUPS_FIRST"
    ];
    shellAliases = {
      l = "ls -lah";
      lg = "lazygit";
      sys = "systemctl status";
      syr = "systemctl restart";
      k = "kubectl";
      # Container aliases are podman-only; modules/podman.nix sets
      # dockerCompat = false, so there is no `docker` binary to fall back on.
      # The d* names are kept for muscle memory but run podman-compose.
      dps = "podman-compose ps";
      dup = "podman-compose up -d --build --remove-orphans";
      dwn = "podman-compose down";
      pps = "podman-compose ps";
      pup = "podman-compose up -d";
      pwn = "podman-compose down";
      n = "nvim .";
      zkdir = "cd ~/code/zettelkasten/";
    };
    interactiveShellInit = ''
      # `t <name>`: attach-or-create a tmux session named <name> (defaults to the
      # current directory name). From inside tmux it switches to the session,
      # creating it if needed. Pairs with the tmux config in modules/tmux.nix.
      t() {
        local name="''${1:-''${PWD##*/}}"
        if [[ -n "''${TMUX:-}" ]]; then
          tmux switch-client -t "$name" 2>/dev/null || tmux new-session -s "$name"
        elif tmux has-session -t "$name" 2>/dev/null; then
          tmux attach-session -t "$name"
        else
          tmux new-session -s "$name"
        fi
      }

      # `tk`: kill the tmux session the shell is currently in, closing every
      # window in it (neovim, lazygit, ...). Only ever touches the current session.
      # Outside tmux, `tk <name>` kills that named session.
      tk() {
        if [[ -n "''${TMUX:-}" ]]; then
          tmux kill-session
        elif [[ -n "''${1:-}" ]]; then
          tmux kill-session -t "$1" 2>/dev/null
        fi
      }
    '';
    ohMyZsh = {
      enable = true;
      # theme = "fino";
      theme = "dogenpunk";
      plugins = [
        "git"
        "z"
      ];
    };
  };

  # Prevent zsh new user dialog by creating .zshrc
  system.userActivationScripts.zshrc = "touch .zshrc";

  # X11 keymap (if needed for any graphical applications)
  services.xserver.xkb = {
    layout = "de";
    variant = "";
  };

  # Journald log retention. NixOS defaults to a percentage of the filesystem,
  # which on small VM disks lets logs consume hundreds of MBs — enough to
  # wedge nix-collect-garbage when /nix hits 100%. 50M is plenty for
  # debugging while keeping the system functional under disk pressure.
  services.journald.settings.Journal.SystemMaxUse = "50M";

  # Enable SSH
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "prohibit-password";
      PasswordAuthentication = false;
    };
  };

  # Prometheus node exporter. Was duplicated as `enable = true; enabledCollectors
  # = ["systemd" "processes"];` across every single host file; centralised here
  # instead. `interrupts` and `ntp` are added on top of the previous pair —
  # meminfo/cpu/diskstats/filesystem/loadavg/netdev/... are already on by
  # default in the node_exporter binary and need no flag. Host-specific
  # exporters (postgres, etc.) stay declared in their own host files; this only
  # covers the node exporter every host shares.
  # On by default fleet-wide: mkDefault so the two bootstrap images
  # (hosts/iso, hosts/minimal) can switch it off without 17 other hosts having
  # to opt in and one of them eventually being forgotten.
  services.loki-logs.enable = lib.mkDefault true;

  services.prometheus.exporters.node = {
    enable = true;
    enabledCollectors = ["systemd" "processes" "interrupts" "ntp"];
  };

  # Mosh (mobile shell) for roaming/high-latency phone access. It bootstraps over
  # SSH, then switches to its own UDP protocol. openFirewall = true opens the
  # mosh UDP range (60000-61000) on every interface. Mosh needs UDP 60000-61000
  # reachable from the client: on the Nebula overlay those ports must also be
  # allowed by the host's nebula inbound rules and firewall. Connect to the
  # host's overlay name/IP and pick "mosh" in the client (Blink Shell / Termius on iOS).
  #
  # This also covers `moshi-hook host setup` (Easy Pair SSH/Mosh) on hosts
  # running the Moshi daemon — the key it wants to add is already the "iPhone"
  # key below, so that command never needs to be run.
  programs.mosh = {
    enable = true;
    openFirewall = true;
  };

  # Who may SSH in. The account itself (admin, groups) is declared in base.nix.
  homelab.users.amadeus = {
    sshKeys = import ../lib/ssh-keys.nix;
  };

  # Enable sudo for wheel group
  security.sudo.wheelNeedsPassword = false;

  # Common packages
  environment.systemPackages = with pkgs; [
    # keep-sorted start
    bind
    busybox
    curl
    fd
    file
    fzf
    ghostty.terminfo
    git
    gnused
    gzip
    htop
    iproute2
    iputils
    jq
    kitty.terminfo
    mtr
    pv
    ripgrep
    rsync
    tmux
    traceroute
    tree
    unzip
    vim
    wget
    yq
    zip
    # keep-sorted end
  ];

  # Networking basics - DHCP disabled, using static IPs per host
  networking.useDHCP = lib.mkDefault false;
  networking.nameservers = lib.mkDefault ["192.168.2.145" "192.168.2.1"];
  networking.search = ["homelab.internal" "homelab.local"];

  # Enable QEMU guest agent (for Proxmox)
  services.qemuGuest.enable = true;

  # Ensure the qemu-guest-agent service starts on boot
  systemd.services.qemu-guest-agent = {
    wantedBy = ["multi-user.target"];
  };

  # Turn a hung guest into a reboot instead of a silent outage: `agents` froze
  # on 2026-11-07 with nothing in its journal and stayed down for 12 h.
  #   * Kernel: panic on a soft lockup or on a task stuck in D state, and
  #     reboot 10 s after any panic. watchdog_thresh 30 (soft lockup after
  #     60 s) and a 600 s hung-task timeout leave room for vCPU steal on the
  #     shared PVE host and for PBS backups' fs-freeze.
  #   * console=ttyS0 sends kernel and panic text to the serial port
  #     (`qm terminal <vmid>`); tty0 stays last, so it remains the console
  #     userspace writes to and the one the Proxmox web UI shows.
  #   * systemd pets the i6300esb watchdog (iac/main.tf, `watchdog` block) so a
  #     guest that hangs without panicking is reset by QEMU after 30 s. On a VM
  #     without that device systemd only logs that it found no watchdog.
  boot.kernelParams = [
    "console=ttyS0,115200"
    "console=tty0"
    "panic=10"
    "softlockup_panic=1"
    "hung_task_panic=1"
  ];
  boot.kernel.sysctl = {
    "kernel.hung_task_timeout_secs" = 600;
    "kernel.watchdog_thresh" = 30;
  };
  systemd.settings.Manager = {
    RuntimeWatchdogSec = "30s";
    RebootWatchdogSec = "10m";
  };

  # Boot loader configuration is handled by disko module
  # See modules/disko-config.nix for partition and boot setup

  # System state version (don't change this after initial installation)
  system.stateVersion = "25.05";
}
