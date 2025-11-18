{
  config,
  pkgs,
  lib,
  ...
}: {
  config = lib.mkIf (config.desktop.enable && config.desktop.environment == "niri") {
    # Niri specific configuration
    programs.niri.enable = true;
    # Configuration will be handled by user's home-manager

    # Niri-specific packages (not in common)
    environment.systemPackages = with pkgs; [
      # Terminal and launcher
      alacritty
      fuzzel

      # Status bar and utilities
      waybar
      swaybg
      swaylock
      swayidle

      # Screenshots and screen recording
      grim
      slurp
      wf-recorder
      wl-clipboard
      wl-mirror

      # File management plugins
      xfce.thunar-archive-plugin

      # Network management applet
      networkmanagerapplet

      # Audio control
      pavucontrol
      pamixer

      # Bluetooth
      blueman

      # Notification daemon
      dunst
      libnotify

      # Polkit agent
      polkit_gnome

      # Color picker
      grimblast

      # PDF viewer
      evince

      # Image viewer
      loupe

      # Text editor
      gnome-text-editor

      # System monitor
      btop
    ];

    # Enable required services
    services = {
      # Auto-mount USB drives
      gvfs.enable = true;
      udisks2.enable = true;

      # Power management
      power-profiles-daemon.enable = true;
      auto-cpufreq.enable = lib.mkDefault false;
    };

    # Enable X11 for compatibility
    services.xserver.enable = true;

    # Enable polkit
    security.polkit.enable = true;

    # Enable portal for GTK/Qt applications
    xdg.portal = {
      enable = true;
      extraPortals = [pkgs.xdg-desktop-portal-gtk];
    };
  };
}

