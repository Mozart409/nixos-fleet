{
  config,
  pkgs,
  lib,
  ...
}: {
  config = lib.mkIf (config.desktop.enable && config.desktop.environment == "kde") {
    # KDE Plasma specific configuration
    services.xserver.enable = true;
    services.displayManager = {
      sddm = {
        enable = true;
        theme = "breeze";
      };
      defaultSession = "plasma";
    };
    services.desktopManager.plasma6.enable = true;

    # KDE-specific packages and integration (not in common)
    environment.systemPackages = with pkgs; [
      # Core KDE applications
      kdePackages.kate
      kdePackages.konsole
      kdePackages.kcalc
      kdePackages.ark
      kdePackages.okular
      kdePackages.gwenview
      kdePackages.spectacle
      
      # KDE integration
      kdePackages.plasma-browser-integration
      kdePackages.kdeconnect-kde
      kdePackages.plasma-pa
      
      # Additional utilities
      kdePackages.krunner
      kdePackages.systemsettings
      kdePackages.kinfocenter
      
      # Development tools
      kdePackages.kdevelop
      
      # Multimedia
      kdePackages.kdenlive
    ];

    # KDE Plasma settings
    programs.kdeconnect.enable = true;

    # Enable KDE services
    services = {
      # Power management
      power-profiles-daemon.enable = true;
      
      # Bluetooth is handled in common desktop config
      
      # Printing
      printing.enable = true;
      
      # Auto-mount USB drives
      gvfs.enable = true;
      udisks2.enable = true;
    };

    # Enable polkit
    security.polkit.enable = true;
    
    # KDE-specific settings
    # KDE partition manager can be installed as a package instead

    # KDE theming and appearance
    environment.sessionVariables = {
      QT_QPA_PLATFORMTHEME = lib.mkForce "kde";
    };
  };
}