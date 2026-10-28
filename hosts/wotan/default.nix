{
  config,
  pkgs,
  inputs,
  lib,
  username,
  ...
}: let
  # llama-server's API key (secrets/llama-cpp-api-key.age). Everything that
  # uses it is gated on the file, so wotan still evaluates before it exists.
  # A flake only sees git-tracked files: `git add` the .age file or this stays
  # false and llama-server runs without a key (a warning says so).
  llamaCppApiKey = builtins.pathExists ../../secrets/llama-cpp-api-key.age;
  # pi's API key (secrets/pi-env.age), gated the same way.
  piEnv = builtins.pathExists ../../secrets/pi-env.age;

  # The AI units the quickshell panel can switch on and off. One list for both
  # halves: home-manager renders the panel from it
  # (desktop.quickshell.serviceToggles) and the polkit rule below lets the user
  # start/stop/restart exactly these units. Adding a unit here does both.
  aiServiceToggles = [
    {
      unit = "llama-cpp.service";
      label = "llama.cpp";
      note = "~9 GiB VRAM";
      gpu = true;
    }
    {
      unit = "comfyui.service";
      label = "ComfyUI";
      note = "VRAM per model";
      gpu = true;
    }
    {
      unit = "sillytavern.service";
      label = "SillyTavern";
      note = "chat UI";
    }
  ];
in {
  imports = [
    # Disko configuration (must come before hardware-config)
    inputs.disko.nixosModules.disko
    ./disko-config.nix

    # Hardware configuration
    ./hardware-configuration.nix

    # Agenix for secrets management
    inputs.agenix.nixosModules.default

    # What wotan shares with the fleet: timezone, locale, keymap, flakes,
    # trusted-users, the amadeus account. Only base.nix -- never common.nix or
    # server.nix, which start sshd (see the assertions below).
    ../../modules/base.nix

    # Shared NixOS modules (aggregator — each gated by its own enable flag)
    ../../modules/wotan

    # Desktop configuration
    ./desktop-config.nix

    # Nebula overlay client (amartum + mozart409 tenants)
    ./nebula.nix
  ];

  # Host-specific settings
  networking.hostName = "wotan";

  # Host-specific DNS settings
  # 192.168.2.145 = local Unbound resolver (primary)
  # 192.168.2.1   = router fallback
  # 1.1.1.1       = Cloudflare public fallback
  networking.nameservers = ["192.168.2.145" "192.168.2.1" "1.1.1.1"];

  # Static IP configuration for enp38s0 (main Ethernet)
  networking.useDHCP = lib.mkForce false;
  networking.interfaces.enp38s0.ipv4.addresses = [
    {
      address = "192.168.2.71";
      prefixLength = 24;
    }
  ];
  networking.defaultGateway = {
    address = "192.168.2.1";
    interface = "enp38s0";
  };

  nix.settings = {
    download-buffer-size = 4 * 1024 * 1024 * 1024;
    substituters = lib.mkAfter ["https://cache.int.oyabu.cc/ventara"];
    trusted-public-keys = lib.mkAfter [
      "ventara:GbJNF0XM+B6Ow4Bq4Y7P0t8opAr28zNIyUjRBtbDwDw="
    ];
  };

  # Bootloader configuration
  boot.loader.systemd-boot.enable = true;
  boot.loader.systemd-boot.configurationLimit = 3;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.timeout = 5;

  # /tmp lives on the root partition, so nothing resets it between the daily
  # systemd-tmpfiles pass (q /tmp ... 10d). Wipe it on boot instead.
  boot.tmp.cleanOnBoot = true;

  # Enable aarch64 emulation for cross-compilation (e.g., building aarch64 ISOs)
  boot.binfmt.emulatedSystems = ["aarch64-linux"];

  # Desktop environment configuration
  desktop.enable = true;

  # Security hardening
  security.hardening = {
    enable = true;
    firewall.allowedTCPPorts = [];
    audit.enable = false; # Enable for security auditing (generates logs)
  };

  # wotan has no inbound SSH: it deploys only itself and is not a colmena node.
  # Bots may edit this config, and fleet modules (modules/common.nix) turn sshd
  # on, so fail evaluation -- the pre-push gate and switch.sh both evaluate
  # wotan -- rather than trust that nobody re-enables it. security.hardening.ssh
  # only hardens sshd's settings; it does not start it.
  assertions = let
    sshFlag = lib.any (lib.hasPrefix "--ssh");
  in [
    {
      assertion = !config.services.openssh.enable;
      message = "wotan must not run sshd (services.openssh.enable): it has no inbound SSH by design. Was modules/common.nix imported?";
    }
    {
      assertion = !(lib.elem 22 config.networking.firewall.allowedTCPPorts);
      message = "wotan must not open TCP 22 in networking.firewall.allowedTCPPorts.";
    }
    {
      assertion = !(sshFlag config.services.tailscale.extraUpFlags || sshFlag config.services.tailscale.extraSetFlags);
      message = "wotan must not enable Tailscale SSH (--ssh in services.tailscale.extra{Up,Set}Flags).";
    }
  ];

  # k3s pod/overlay networking must bypass the host firewall
  networking.firewall.trustedInterfaces = ["cni0" "flannel.1"];

  # Display manager auto-login (KDE specific)
  services.displayManager.autoLogin = lib.mkIf (config.desktop.environment == "kde") {
    enable = true;
    user = username;
  };

  # MOZA sim-racing wheelbase support
  hardware.moza.enable = true;

  # System-managed MCP servers for Claude Code
  programs.claudeCodeMcp.enable = true;

  services.xserver.videoDrivers = ["nvidia"];

  hardware.nvidia = {
    # Modesetting is required.
    modesetting.enable = true;

    # Nvidia power management. Experimental, and can cause sleep/suspend to fail.
    # Enable this if you have graphical corruption issues or application crashes after waking
    # up from sleep. This fixes it by saving the entire VRAM memory to /tmp/ instead
    # of just the bare essentials.
    powerManagement.enable = true;

    # Fine-grained power management. Turns off GPU when not in use.
    # Experimental and only works on modern Nvidia GPUs (Turing or newer).
    powerManagement.finegrained = false;

    # Use the NVidia open source kernel module (not to be confused with the
    # independent third-party "nouveau" open source driver).
    # Support is limited to the Turing and later architectures. Full list of
    # supported GPUs is at:
    # https://github.com/NVIDIA/open-gpu-kernel-modules#compatible-gpus
    # Only available from driver 515.43.04+
    # Currently alpha-quality/buggy, so false is currently the recommended setting.
    open = false;

    # Enable the Nvidia settings menu,
    # accessible via `nvidia-settings`.
    nvidiaSettings = true;

    # Optionally, you may need to select the appropriate driver version for your specific GPU.
    package = config.boot.kernelPackages.nvidiaPackages.stable;
  };

  # Enable NVIDIA Container Toolkit so Podman can pass GPUs to containers
  # via CDI (--device nvidia.com/gpu=all).
  hardware.nvidia-container-toolkit.enable = true;

  # Host-specific packages
  environment.systemPackages = with pkgs; [
    steam
    heroic
    mangohud
    bcachefs-tools
  ];

  virtualisation.podman = {
    enable = true;
    dockerCompat = false;
    defaultNetwork.settings.dns_enabled = true;
  };

  # v2 registries.conf schema. Replaces the deprecated
  # `virtualisation.containers.registries.search`, which emitted the v1
  # `[registries.search]` table; `unqualified-search-registries` is its v2
  # equivalent. Setting `settings` also drops nixpkgs' default
  # `registry = [docker.io quay.io]`, which configures those registries but
  # does NOT make them searchable for unqualified names.
  virtualisation.containers.registries.settings = {
    unqualified-search-registries = ["quay.io"];
  };

  programs.steam = {
    enable = true;
    extraCompatPackages = with pkgs; [
      proton-ge-bin
    ];
    package = pkgs.steam.override {
      extraBwrapArgs = [
        "--bind"
        "/mnt/games"
        "/mnt/games"
      ];
    };
  };
  # gamescope micro-compositor — wraps games so Hyprland sees one
  # well-behaved window (fixes Xwayland fullscreen/cursor weirdness,
  # e.g. S.T.A.L.K.E.R. GAMMA via Heroic).
  #
  # capSysNice MUST stay false: it installs gamescope as a setcap wrapper
  # at /run/wrappers/bin, which fails ("failed to inherit capabilities")
  # inside Heroic's no-new-privs bubblewrap sandbox and bails instantly.
  # false installs the plain binary at /run/current-system/sw/bin, which
  # the sandbox can run (we only forgo realtime scheduling priority).
  programs.gamescope = {
    enable = true;
    capSysNice = false;
  };
  services.tailscale.enable = true;

  # Trust Homelab CA root certificate (step-ca)
  security.pki.certificates = [
    ''
      -----BEGIN CERTIFICATE-----
      MIIBqDCCAU6gAwIBAgIRALQDGl7A1VqHYulOxqghMAUwCgYIKoZIzj0EAwIwMjET
      MBEGA1UEChMKSG9tZWxhYiBDQTEbMBkGA1UEAxMSSG9tZWxhYiBDQSBSb290IENB
      MB4XDTI2MDQxNzIwMDQzMloXDTM2MDQxNDIwMDQzMlowMjETMBEGA1UEChMKSG9t
      ZWxhYiBDQTEbMBkGA1UEAxMSSG9tZWxhYiBDQSBSb290IENBMFkwEwYHKoZIzj0C
      AQYIKoZIzj0DAQcDQgAE43kC/jM9k+aC3yS1m1ckSohIHFRdU1gZvZVkW1TyiUJm
      i88gkJJl0B1NrU8ZjBwT/rthgpPyXu6P8ZiUFcb5yaNFMEMwDgYDVR0PAQH/BAQD
      AgEGMBIGA1UdEwEB/wQIMAYBAf8CAQEwHQYDVR0OBBYEFIVsuIWilVCzeUOnHLhq
      kHKB5uYhMAoGCCqGSM49BAMCA0gAMEUCIQDuctLl8ySFXqgAsJV4E7cEM3ezyvdo
      eC4NJYiSUAa8xwIgcjnD5fki6RlgJisn80mg/nARJNvNHqjazM3j1b4x4/4=
      -----END CERTIFICATE-----
    ''
  ];

  # opencode headless server — persistent background service so every new
  # opencode session attaches to the same server instead of spawning a new one.
  # A zsh function in configs/shell.nix (`opencode` → `opencode --server
  # $OPENCODE_SERVER_URL "$PWD"`) makes this transparent. Commands run
  # in the server's environment, not the attaching shell's: devshell/direnv
  # tools are only available via `nix develop -c ...`.
  services.opencode-serve = {
    enable = true;
    hostname = "127.0.0.1";
    port = 4096;
    # Runs as the agent account and sees only ~/code and the agent's own home,
    # the same confinement agent-run gives interactive claude (agent-user.nix).
    user = config.wotan.agentUser.user;
    group = config.wotan.agentUser.user;
    homeBindPaths = [config.wotan.agentUser.codeDir config.wotan.agentUser.home];
    # password = "";  # Set for auth; empty = no basic-auth.
    # The server process (not the attaching shell) connects to MCP servers, so
    # secrets referenced via {env:VAR} in opencode.json must be in the
    # service's environment. The agenix secret is already in KEY=value format.
    # NOTE: restart the service after re-encrypting the secret (token rotation).
    environmentFiles = [
      config.age.secrets.axon-gateway-env.path
      config.age.secrets.ventara-gateway-env.path
      # Basic auth; the server reads OPENCODE_SERVER_PASSWORD from this env
      # file, and clients pass the same value as OPENCODE_PASSWORD (home.nix).
      config.age.secrets.opencode-server-password.path
    ];
    # Raw-value secret (not KEY=value), for {env:CONTEXT7_API_KEY}.
    credentialEnvironment.CONTEXT7_API_KEY = config.age.secrets.context7-api-key.path;
    readWritePaths = [config.wotan.agentUser.codeDir config.wotan.agentUser.home];
    # The bot signing key (not a login key anywhere), so the agents can sign
    # commits but can't authenticate/push. One ssh-agent each for opencode and
    # Claude Code (modules/home/packages/claude.nix). The key stays in
    # amadeus's ~/.ssh; systemd hands it to them as a credential that every
    # agent session has hidden.
    signing = {
      keyFile = "/home/${username}/.ssh/id_ed25519_signing";
      publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAII0yU9qnU/StErCjgpV/M5h68Por1yRC21uqdO0eF6M9 bot-signing@wotan";
      agents = ["opencode" "claude"];
    };
    # systemd (PID 1) reads the secrets above before entering the sandbox, so
    # /run/agenix can be hidden from every tool. amadeus's home is already
    # out of view (homeBindPaths).
    inaccessiblePaths = [
      "/run/agenix"
      "/run/agenix.d"
      "${config.wotan.agentUser.home}/.claude/.credentials.json"
    ];
  };

  # Claude Code and opencode run as `agent` (modules/wotan/agent-user.nix):
  # no sudo, and every agent process sees only ~/code of amadeus's home.
  # amadeus starts them with `sudo agent-run claude|opencode` (the `claude`
  # zsh function does that); the gateway tokens reach them as credentials.
  home-manager.users.${config.wotan.agentUser.user} = import ./agent-home.nix;
  wotan.agentUser = {
    enable = true;
    owner = username;
    credentials =
      {
        axon-gateway = config.age.secrets.axon-gateway-env.path;
        ventara-gateway = config.age.secrets.ventara-gateway-env.path;
      }
      # OPENCODE_API_KEY for pi.
      // lib.optionalAttrs piEnv {
        pi = config.age.secrets.pi-env.path;
      };
    # Private networks are closed to the agents; these are the hosts they
    # use: axon-gateway (MCP, Hindsight), Forgejo (git over ssh :2222) and
    # the ventara gateway axon.int.oyabu.cc on nebula-amartum.
    network.allow = let
      inherit ((import ../../lib/hosts.nix).hosts) mcp forgejo;
    in [mcp.ip forgejo.ip "172.16.10.10"];
    flakeRepos = ["${config.wotan.agentUser.codeDir}/yggdrasil"];
  };
  # The server loads plugins and config from ~/.config/opencode once, at
  # startup. home-manager rewrites those files without touching this unit, so
  # a switch left it running the old plugin until a manual restart. Contents,
  # not `source`: a `./file` source is a path into the whole flake source and
  # would restart the server on every commit.
  systemd.services.opencode-serve.restartTriggers = let
    files = config.home-manager.users.${config.wotan.agentUser.user}.home.file;
    contents = f:
      if f.text != null
      then f.text
      else builtins.hashFile "sha256" f.source;
  in
    map (name: contents files.${name})
    (lib.filter (lib.hasPrefix ".config/opencode/") (lib.attrNames files));

  # Swap on zram — helps avoid OOM during large builds and LLM inference
  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 50;
  };

  # llama.cpp inference server (llama-server, OpenAI-compatible API on
  # 127.0.0.1:10808/v1). Stock nixpkgs module. cudaSupport is off globally
  # (lib/mkConfigs.nix), so the package is overridden to the CUDA build; the
  # plain pkgs.llama-cpp runs on the CPU ("no usable GPU found", ~4 tok/s).
  # Every settings key becomes `--key value` on ExecStart, so values must not
  # contain spaces or quotes. Flags checked against tools/server/README.md at
  # llama.cpp tag b10408 (the locked package version).
  #
  # VRAM budget (RTX 3060, 11.6 GiB; Hyprland holds ~1.5 GiB → ~10 GiB free):
  # Q6_K weights ~6.9 GiB. Qwen3.5 is hybrid Gated-DeltaNet: only 8 of 32
  # layers keep a KV cache, 4 KV heads x 256 dim x 2 (K+V) x 8 layers = 16384
  # values/token, i.e. 32 KiB at f16 or ~17 KiB at q8_0, so 65536 tokens cost
  # ~1.1 GiB. Plus the small recurrent state and ~0.5-1 GiB of compute buffers
  # that is ~9 GiB. If it OOMs at load, halve ctx-size or switch to the
  # Q4_K_M file from the same repo.
  services.llama-cpp = {
    enable = true;
    package = pkgs.llama-cpp.override {cudaSupport = true;};
    settings =
      {
        host = "127.0.0.1";
        port = 10808;
        # Downloaded by the user into the tmpfiles dir below; the DynamicUser
        # service cannot read /home (ProtectHome), but /var/lib is fine.
        model = "/var/lib/llama-cpp-models/Qwen3.5-9B-Uncensored-HauhauCS-Aggressive-Q6_K.gguf";
        n-gpu-layers = "all";
        flash-attn = "on";
        cache-type-k = "q8_0";
        cache-type-v = "q8_0";
        # One slot gets the whole context; the default (auto) splits it.
        parallel = 1;
        ctx-size = 65536;
        # Thinking off by default (sets the template's enable_thinking=false).
        # A request can still turn it on with
        # "chat_template_kwargs": {"enable_thinking": true}.
        reasoning = "off";
        # Qwen3.5 model card, non-thinking mode for general tasks
        # (repetition_penalty 1.0 is already llama.cpp's default).
        temp = 0.7;
        top-p = 0.8;
        top-k = 20;
        min-p = 0.0;
        presence-penalty = 1.5;
      }
      # API key (age.secrets.llama-cpp-api-key below). --api-key-file reads one
      # key per line, each line verbatim (no trimming), skipping empty lines and
      # lines starting with #. /health, /v1/health, /models, /v1/models and the
      # web UI's static files stay unauthenticated (tools/server/server-http.cpp
      # at b10408); every other endpoint wants `Authorization: Bearer <key>` (or
      # `X-Api-Key: <key>`). optionalAttrs, not mkIf: settings is a freeform
      # `attrs` submodule, which hands an mkIf to the command line unevaluated.
      // lib.optionalAttrs llamaCppApiKey {
        api-key-file = "/run/credentials/llama-cpp.service/api-key";
      };
  };
  systemd.services.llama-cpp = {
    # Not started at boot: it pins ~9 GiB of VRAM. `sudo systemctl start llama-cpp`.
    wantedBy = lib.mkForce [];
    # systemd (as root) copies the root-only agenix file into the unit's
    # credential dir, where the DynamicUser can read it; only the path reaches
    # ExecStart.
    serviceConfig.LoadCredential = lib.mkIf llamaCppApiKey "api-key:${config.age.secrets.llama-cpp-api-key.path}";
    # A new key (a different .age file) restarts the unit on switch if it is
    # running; a stopped unit stays stopped.
    restartTriggers = lib.mkIf llamaCppApiKey [config.age.secrets.llama-cpp-api-key.file];
  };
  warnings = lib.optional (!llamaCppApiKey) "wotan: secrets/llama-cpp-api-key.age is missing (or not git-added), so llama-server runs without an API key";

  # SillyTavern (stock nixpkgs module, global mode): web UI on
  # http://127.0.0.1:8045, loopback only. `listen` stays at its default
  # (false), which binds 127.0.0.1; IPv6 is off in the default config. Port
  # 8045 rather than the default 8000, which dev servers like to take.
  # Started at boot: it is a small node process with no dependency on
  # llama-cpp, so it never pulls the model into VRAM. State, chats and
  # per-user secrets live in /var/lib/SillyTavern/data/default-user.
  services.sillytavern = {
    enable = true;
    port = 8045;
    # The module's default configFile points at <pkg>/lib/node_modules/
    # sillytavern/config.yaml, which the package does not ship (upstream only
    # has default/config.yaml), leaving the tmpfiles symlink dangling. Use the
    # shipped defaults: whitelistMode on for 127.0.0.1/::1, basic auth and
    # user accounts off. SillyTavern only rewrites config.yaml when keys are
    # missing, which never happens with its own default file.
    configFile = "${config.services.sillytavern.package}/lib/node_modules/sillytavern/default/config.yaml";
  };
  systemd.services.sillytavern = {
    # Not started at boot: start/stop via the Quickshell AI toggles or manually.
    wantedBy = lib.mkForce [];
    # config.yaml keys can be overridden by SILLYTAVERN_<KEY> env vars
    # (src/util.js keyToEnv). No browser to open from a system service.
    environment.SILLYTAVERN_BROWSERLAUNCH_ENABLED = "false";
    # Seed the llama.cpp key into SillyTavern's secret store, so the Text
    # Completion -> llama.cpp connection needs only the server URL. The key
    # comes in as a systemd credential (never in the store or argv) and is
    # upserted as the active `api_key_llamacpp` entry with the fixed id
    # "agenix"; other secrets, and llama.cpp keys added in the UI, are kept
    # (the latter deactivated, so the agenix key is in use after every start).
    # Same parsing as llama-server: the first non-empty line not starting
    # with #.
    serviceConfig.LoadCredential = lib.mkIf llamaCppApiKey "llama-cpp-api-key:${config.age.secrets.llama-cpp-api-key.path}";
    restartTriggers = lib.mkIf llamaCppApiKey [config.age.secrets.llama-cpp-api-key.file];
    preStart = lib.mkIf llamaCppApiKey ''
      dir=/var/lib/SillyTavern/data/default-user
      f="$dir/secrets.json"
      umask 077
      mkdir -p "$dir"
      [ -s "$f" ] || echo '{}' > "$f"
      # Old flat files ({"key": "value"}) are migrated by SillyTavern
      # itself, but only while no value is an array, so leave those alone.
      if ${lib.getExe pkgs.jq} -e 'any(.[]; type == "string")' "$f" > /dev/null; then
        echo "secrets.json is in the old flat format; not seeding the llama.cpp key" >&2
        exit 0
      fi
      ${lib.getExe pkgs.jq} --rawfile raw "$CREDENTIALS_DIRECTORY/llama-cpp-api-key" '
        ($raw | split("\n") | map(select(length > 0 and (startswith("#") | not))) | first) as $key
        | if $key == null then error("llama-cpp-api-key credential is empty") else . end
        | .api_key_llamacpp = (
            [(.api_key_llamacpp // [])[] | select(.id != "agenix") | .active = false]
            + [{id: "agenix", value: $key, label: "agenix", active: true}]
          )
      ' "$f" > "$f.tmp"
      mv "$f.tmp" "$f"
    '';
  };

  # ComfyUI (stock nixpkgs module): web UI and API on http://127.0.0.1:8188,
  # loopback only (the module's default listen = 127.0.0.1 + ::1). cudaSupport
  # is off globally, so the plain package runs torch on the CPU. Rather than a
  # from-source CUDA torch (hours to build, and not what cache.nixos-cuda.org
  # builds), its Python set swaps in the prebuilt PyTorch wheels: torch-bin
  # and torchvision-bin, CUDA 13, which driver 595 supports. Everything else
  # that depends on torch (kornia, spandrel, transformers, ...) is rebuilt
  # against them; comfy-kitchen stays without its CUDA kernels and falls back
  # to its eager/triton backends.
  services.comfyui = {
    enable = true;
    package = pkgs.comfyui.override {
      # python3.override with `self`, not overrideScope: comfyui builds its env
      # with withPackages, which would drop scope overrides.
      python3 = let
        python = pkgs.python3.override {
          self = python;
          packageOverrides = final: _prev: {
            torch = final.torch-bin;
            torchvision = final.torchvision-bin;
          };
        };
      in
        python;
    };
    extraArgs = [
      "--preview-method=auto"
      # Models live in an amadeus-owned dir (tmpfiles below), so downloads need
      # no sudo; the state dir /var/lib/comfyui is 0700 comfyui. Read-only for
      # the service, which ProtectSystem=strict allows.
      "--extra-model-paths-config=${(pkgs.formats.yaml {}).generate "extra_model_paths.yaml" {
        wotan = {
          base_path = "/var/lib/comfyui-models";
          checkpoints = "checkpoints";
          diffusion_models = "diffusion_models";
          text_encoders = "text_encoders";
          vae = "vae";
          loras = "loras";
          clip_vision = "clip_vision";
          controlnet = "controlnet";
          upscale_models = "upscale_models";
          embeddings = "embeddings";
        };
      }}"
    ];
  };
  # Not started at boot: llama-cpp already pins ~9 GiB of the 3060's 12 GiB,
  # and ComfyUI keeps loaded models in VRAM. `sudo systemctl start comfyui`.
  systemd.services.comfyui.wantedBy = lib.mkForce [];
  # torch 2.14 routes some ops (e.g. bmm outer products in the text encoder)
  # through Triton kernels, which JIT-compile a C helper at first use and fail
  # with "Failed to find C compiler" (no cc in the unit's PATH). Fall back to
  # the regular CUDA kernels instead.
  systemd.services.comfyui.environment.TORCH_DISABLE_NATIVE_JIT = "1";

  # Quickshell toggles for the AI units (aiServiceToggles at the top):
  # ServiceTogglesWidget.qml, bottom-left on an empty workspace, driven by the
  # quickshell-units script (modules/home/packages/quickshell.nix).
  home-manager.users.${username}.desktop.quickshell.serviceToggles = {
    enable = true;
    title = "AI";
    units = aiServiceToggles;
  };
  # ...and the polkit rule that makes those clicks work without sudo or a
  # password prompt: the user may start, stop and restart exactly these units,
  # nothing else (no enable/mask/edit, no other unit). No subject.local /
  # subject.active check on purpose: quickshell runs under user@.service, not
  # inside the logind session, so polkit sees it as neither. Appended to the
  # rules in modules/desktop/user-experience.nix (security.polkit.enable is set
  # in modules/desktop/default.nix).
  security.polkit.extraConfig = ''
    // aiServiceToggles (hosts/wotan/default.nix): quickshell service toggles
    polkit.addRule(function(action, subject) {
      if (action.id != "org.freedesktop.systemd1.manage-units" ||
          subject.user != ${builtins.toJSON username}) {
        return polkit.Result.NOT_HANDLED;
      }
      var units = ${builtins.toJSON (map (t: t.unit) aiServiceToggles)};
      var verbs = ["start", "stop", "restart"];
      if (units.indexOf(action.lookup("unit")) >= 0 &&
          verbs.indexOf(action.lookup("verb")) >= 0) {
        return polkit.Result.YES;
      }
      return polkit.Result.NOT_HANDLED;
    });
  '';

  # System state version
  system.stateVersion = "24.11";

  # Ensure storage mount is owned by the primary user and create models directory
  systemd.tmpfiles.rules = [
    "Z /mnt/storage 0755 ${username} users -"
    "d /home/${username}/models 0755 ${username} users -"
    # GGUF files for services.llama-cpp, downloaded without sudo
    "d /var/lib/llama-cpp-models 0755 ${username} users -"
    # Model files for services.comfyui (extra_model_paths.yaml above)
    "d /var/lib/comfyui-models 0755 ${username} users -"
    "d /var/lib/comfyui-models/checkpoints 0755 ${username} users -"
    "d /var/lib/comfyui-models/diffusion_models 0755 ${username} users -"
    "d /var/lib/comfyui-models/text_encoders 0755 ${username} users -"
    "d /var/lib/comfyui-models/vae 0755 ${username} users -"
    "d /var/lib/comfyui-models/loras 0755 ${username} users -"
    "d /var/lib/comfyui-models/clip_vision 0755 ${username} users -"
    "d /var/lib/comfyui-models/controlnet 0755 ${username} users -"
    "d /var/lib/comfyui-models/upscale_models 0755 ${username} users -"
    "d /var/lib/comfyui-models/embeddings 0755 ${username} users -"
  ];

  # Agenix secrets configuration
  age.identityPaths = [
    "/etc/ssh/ssh_host_ed25519_key"
  ];

  age.secrets.context7-api-key = {
    file = ../../secrets/context7-api-key.age;
    mode = "440";
    owner = username;
    group = "users";
  };

  # Raw attic token for switch.sh's `attic push`; home.nix points
  # ~/.config/attic/config.toml at it via token-file. Gated until the .age file
  # exists (`agenix -e attic-push-token-wotan.age`), so eval never breaks.
  age.secrets.attic-push-token-wotan = lib.mkIf (builtins.pathExists ../../secrets/attic-push-token-wotan.age) {
    file = ../../secrets/attic-push-token-wotan.age;
    mode = "400";
    owner = username;
  };

  # Raw llama-server API key (pwgen -s 48 1), one line, no KEY= prefix. Stays
  # root:root 0400: llama-cpp and sillytavern read it through LoadCredential.
  # Gated like attic-push-token-wotan (`agenix -e llama-cpp-api-key.age`).
  age.secrets.llama-cpp-api-key = lib.mkIf llamaCppApiKey {
    file = ../../secrets/llama-cpp-api-key.age;
  };

  age.secrets.axon-gateway-env = {
    file = ../../secrets/axon-gateway-env.age;
    # Owner-only: read (as root) by agent-run's LoadCredential and
    # opencode-serve's EnvironmentFile.
    mode = "400";
    owner = username;
    # Format inside the file: AXON_GATEWAY_TOKEN=ABC123
  };

  # Bearer token for ventara-gateway, the nixos-ventara-ai deployment's own
  # axon-gateway (a separate instance from the homelab one above).
  age.secrets.ventara-gateway-env = {
    file = ../../secrets/ventara-gateway-env.age;
    # Owner-only: read (as root) by agent-run's LoadCredential and
    # opencode-serve's EnvironmentFile.
    mode = "400";
    owner = username;
    # Format inside the file: VENTARA_GATEWAY_TOKEN=ABC123
  };

  # pi's API key, one line: OPENCODE_API_KEY=... Owner-only: read (as root) by
  # agent-run's LoadCredential. Gated until the .age file exists
  # (`agenix -e pi-env.age`).
  age.secrets.pi-env = lib.mkIf piEnv {
    file = ../../secrets/pi-env.age;
    mode = "400";
    owner = username;
  };

  age.secrets.opencode-server-password = {
    file = ../../secrets/opencode-server-password.age;
    mode = "440";
    owner = username;
    group = "users";
    # Format inside the file: OPENCODE_SERVER_PASSWORD=xxxx
  };

  age.secrets.ha-token = {
    file = ../../secrets/ha-token.age;
    mode = "400";
    owner = username;
    # Raw Home Assistant long-lived access token, no KEY= prefix. Read by
    # quickshell-ha (desktop.quickshell.homeAssistant in home.nix).
  };

  age.secrets.hofvarpnir-tui = {
    file = ../../secrets/hofvarpnir-tui.age;
    mode = "400";
    owner = username;
    # Raw hofvarpnir API key (hof_sk_...), no KEY= prefix. Read by the TUI via
    # token_file in the generated ~/.config/hofvarpnir/tui.toml
    # (modules/home/packages/hofvarpnir-tui.nix).
  };

  # Environment variables
  environment.sessionVariables = {
    # Agenix secrets
    CONTEXT7_API_KEY_FILE = config.age.secrets.context7-api-key.path;
    AXON_GATEWAY_TOKEN_FILE = config.age.secrets.axon-gateway-env.path;
    VENTARA_GATEWAY_TOKEN_FILE = config.age.secrets.ventara-gateway-env.path;
    OPENCODE_SERVER_PASSWORD_FILE = config.age.secrets.opencode-server-password.path;

    # NVIDIA Wayland environment variables for better compatibility
    GBM_BACKEND = "nvidia-drm";
    __GLX_VENDOR_LIBRARY_NAME = "nvidia";
    # Disable hardware cursors (fixes flickering/lag on some setups)
    WLR_NO_HARDWARE_CURSORS = "1";
    # Enable VRR/GSync for NVIDIA
    __GL_GSYNC_ALLOWED = "1";
    __GL_VRR_ALLOWED = "1";
    # Hardware video acceleration with NVIDIA
    LIBVA_DRIVER_NAME = "nvidia";
    NVD_BACKEND = "direct";
    # Electron/Chromium apps - use Wayland
    ELECTRON_OZONE_PLATFORM_HINT = "auto";

    # Aquamarine (Hyprland renderer) NVIDIA fixes
    # Disable forcing linear modifiers - can help with scroll lag on NVIDIA
    AQ_FORCE_LINEAR_BLIT = "0";
  };
}
