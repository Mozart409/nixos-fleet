{
  config,
  pkgs,
  lib,
  inputs,
  username,
  ...
}: {
  # Use nixpkgs's hyprland module (not the flake's) — nixpkgs packages glaze
  # properly while the flake's CMakeLists.txt uses FetchContent to clone glaze
  # from GitHub, which has no network access in the sandboxed build.
  # Both are version 0.56.1.
  imports = [
    ./next-wallpaper.nix
  ];

  config = lib.mkIf (config.desktop.enable && config.desktop.environment == "hyprland") {
    desktop.nextWallpaper.enable = true;

    security.sudo.extraConfig = ''
      Defaults!${pkgs.gparted}/bin/gparted env_keep+="DISPLAY WAYLAND_DISPLAY XDG_RUNTIME_DIR"
      Defaults!${pkgs.polkit.bin}/bin/pkexec env_keep+="DISPLAY WAYLAND_DISPLAY XDG_RUNTIME_DIR"
    '';

    # Essential Wayland packages
    environment.systemPackages = with pkgs; [
      # Core utilities
      hyprshot
      slurp
      grim
      wl-clipboard
      cliphist
      playerctl
      satty
      hyprpicker

      # Bar and launcher
      rofi
      wlogout

      # Lockscreen and background
      hyprlock
      hypridle
      hyprlauncher
      hyprtoolkit
      hyprsysteminfo
      # Blue light filter
      inputs.hyprsunset.packages.${pkgs.stdenv.hostPlatform.system}.hyprsunset
      inputs.awww.packages.${pkgs.stdenv.hostPlatform.system}.awww

      # Notifications are NOT installed here. dunst ships a systemd user unit
      # and a D-Bus activation file, and installing it system-wide puts both in
      # /run/current-system/sw, where they start dunst for every session
      # regardless of what home-manager decided. That silently defeats
      # desktop.notifications.backend: dunst would win the race for
      # org.freedesktop.Notifications, unconfigured (home-manager had removed
      # its dunstrc), and quickshell's daemon would get nothing.
      # home-manager's services.dunst installs the package itself when it is
      # the selected backend -- see modules/home-manager/packages/notifications.nix.

      # Hyprland plugins are NOT installed here, and do not add a plugin flake
      # input like `hyprland-plugins` (it would be built against the upstream
      # hyprland flake, not the nixpkgs hyprland we run). They come from
      # pkgs.hyprlandPlugins and are loaded from the home-manager side -- see
      # the plugin list in modules/home-manager/packages/hyprland-configs.nix.

      # Theming
      qt6.qtwayland
      libsForQt5.qtwayland
    ];

    # Display manager
    services.displayManager = {
      defaultSession = "hyprland";
    };

    # Greetd configuration
    services.greetd = {
      enable = true;
      settings = {
        initial_session = {
          command = "${pkgs.hyprland}/bin/start-hyprland";
          user = username;
        };
        default_session = {
          command = "${pkgs.tuigreet}/bin/tuigreet --greeting 'Welcome to NixOS!' --asterisks --remember --time --theme 'border=darkgray;text=white;prompt=cyan;time=cyan;action=cyan;button=darkgray;container=black' --cmd ${pkgs.hyprland}/bin/start-hyprland";
          user = "greeter";
        };
      };
    };

    # Portal configuration
    xdg.portal = {
      enable = true;
      extraPortals = with pkgs; [
        xdg-desktop-portal-gtk
        xdg-desktop-portal-hyprland
      ];
      configPackages = with pkgs; [
        xdg-desktop-portal-hyprland
      ];
    };

    # Hyprland configuration
    programs.hyprland.enable = true;

    # Lockscreen configuration
    security.pam.services.hyprlock = {};

    # Theming integration
    environment.sessionVariables = {
      # Qt theme - use Kvantum directly
      QT_QPA_PLATFORMTHEME = lib.mkForce "kvantum";
      QT_STYLE_OVERRIDE = "kvantum";

      # Wayland compatibility
      MOZ_ENABLE_WAYLAND = "1";
      _JAVA_AWT_WM_NONREPARENTING = "1";

      # Hyprshot screenshot directory
      HYPRSHOT_DIR = "${config.users.users.${username}.home}/Pictures/hyprshot";
    };
  };
}
