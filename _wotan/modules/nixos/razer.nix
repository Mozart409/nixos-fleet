{
  config,
  pkgs,
  lib,
  username,
  ...
}: {
  options.hardware.razer = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable Razer device support with OpenRazer and management tools";
    };
  };

  config = lib.mkIf config.hardware.razer.enable {
    # OpenRazer daemon for Razer hardware support
    hardware.openrazer = {
      enable = true;
      users = [username];
    };

    # Razer management tools
    environment.systemPackages = with pkgs; [
      # Polychromatic - Feature-rich GUI for OpenRazer
      polychromatic

      # RazerGenie - Qt-based GUI alternative
      razergenie

      # CLI tools for scripting and advanced usage
      openrazer-daemon
    ];
  };
}
