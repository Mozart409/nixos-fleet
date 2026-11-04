{
  config,
  inputs,
  lib,
  pkgs,
  ...
}: let
  cfg = config.wotan.minecraft;

  # Vanilla's default game port and Simple Voice Chat's port, which the pack
  # sets in config/voicechat/voicechat-server.properties.
  gamePort = 25565;
  voiceChatPort = 24454;

  # The pack pins its loader in modrinth.index.json: keep the NeoForge version
  # in `package` below in step with it when bumping.
  modpack = pkgs.fetchModrinthModpack {
    pname = "automation";
    version = "4.1.1";
    url = "https://cdn.modrinth.com/data/sl6XzkCP/versions/2buQI0o6/Automation-4.1.1.mrpack";
    packHash = "sha256-cSDNacd5WlIs7np5iWMLyv3z7x0r/TapC06L5JVSznQ=";
    side = "server";
  };

  # The pack marks Controlify as required on the server, but it is client-only
  # and crashes mod loading on a dedicated server.
  serverMods = pkgs.runCommand "automation-server-mods" {} ''
    mkdir $out
    ln -s ${modpack}/mods/* $out/
    rm $out/controlify-*.jar
  '';
in {
  imports = [inputs.nix-minecraft.nixosModules.minecraft-servers];

  options.wotan.minecraft.enable = lib.mkEnableOption "the Automation modpack Minecraft server";

  config = lib.mkIf cfg.enable {
    nixpkgs.overlays = [inputs.nix-minecraft.overlays.default];

    services.minecraft-servers = {
      enable = true;
      # Accepts the Minecraft EULA: https://aka.ms/MinecraftEULA
      eula = true;

      servers.automation = {
        enable = true;
        # Minecraft 1.21.1 targets Java 21; the package defaults to a newer one.
        package = pkgs.neoforgeServers.neoforge-1_21_1-21_1_265.override {
          jre_headless = pkgs.jdk21_headless;
        };
        jvmOpts = "-Xms2G -Xmx6G";
        serverProperties = {
          motd = "Automation";
          server-port = gamePort;
        };

        symlinks.mods = "${serverMods}";
        # Copied, not symlinked: mods rewrite their configs at startup. The copy
        # is reset from the pack on every start.
        files.config = "${modpack}/config";
      };
    };

    # LAN only. Not openFirewall, which would also expose the server on the
    # tailscale and nebula interfaces.
    networking.firewall.interfaces.enp38s0 = {
      allowedTCPPorts = [gamePort];
      allowedUDPPorts = [voiceChatPort];
    };
  };
}
