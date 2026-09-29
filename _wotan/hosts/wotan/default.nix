{
  config,
  pkgs,
  inputs,
  lib,
  username,
  ...
}: {
  imports = [
    # Disko configuration (must come before hardware-config)
    inputs.disko.nixosModules.disko
    ./disko-config.nix

    # Hardware configuration
    ./hardware-configuration.nix

    # Agenix for secrets management
    inputs.agenix.nixosModules.default

    # Shared NixOS modules (aggregator — each gated by its own enable flag)
    ../../modules/nixos

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

  nix.settings.download-buffer-size = 4 * 1024 * 1024 * 1024;

  # Bootloader configuration
  boot.loader.systemd-boot.enable = true;
  boot.loader.systemd-boot.configurationLimit = 5;
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

  # k3s pod/overlay networking must bypass the host firewall
  networking.firewall.trustedInterfaces = ["cni0" "flannel.1"];

  # Display manager auto-login (KDE specific)
  services.displayManager.autoLogin = lib.mkIf (config.desktop.environment == "kde") {
    enable = true;
    user = username;
  };

  # Razer device support
  hardware.razer.enable = true;

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
  # A zsh function in configs/shell.nix (`opencode` → `opencode attach
  # $OPENCODE_SERVER_URL --dir "$PWD"`) makes this transparent. Commands run
  # in the server's environment, not the attaching shell's: devshell/direnv
  # tools are only available via `nix develop -c ...`.
  services.opencode-serve = {
    enable = true;
    hostname = "127.0.0.1";
    port = 4096;
    user = username;
    # password = "";  # Set for auth; empty = no basic-auth.
    # The server process (not the attaching shell) connects to MCP servers, so
    # secrets referenced via {env:VAR} in opencode.json must be in the
    # service's environment. The agenix secret is already in KEY=value format.
    # NOTE: restart the service after re-encrypting the secret (token rotation).
    environmentFiles = [
      config.age.secrets.axon-gateway-env.path
      # Basic auth; clients get it via OPENCODE_SERVER_PASSWORD (home.nix).
      config.age.secrets.opencode-server-password.path
    ];
    # Raw-value secret (not KEY=value), for {env:CONTEXT7_API_KEY}.
    credentialEnvironment.CONTEXT7_API_KEY = config.age.secrets.context7-api-key.path;
    readWritePaths = ["/home/${username}" "/etc/nixos"];
    # Signing-only key (not a login key anywhere) in its own agent, so opencode
    # can sign commits but can't authenticate/push. Private key stays hidden
    # (~/.ssh is in inaccessiblePaths).
    signing = {
      keyFile = "/home/${username}/.ssh/id_ed25519_signing";
      publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAII0yU9qnU/StErCjgpV/M5h68Por1yRC21uqdO0eF6M9 bot-signing@wotan";
    };
    # systemd (PID 1) reads the secrets above before entering the sandbox, so
    # /run/agenix can be hidden from every tool. ~/.gnupg stays visible but
    # without private keys: signing goes through the (unsandboxed) gpg-agent.
    inaccessiblePaths = [
      "/run/agenix"
      "/run/agenix.d"
      "/home/${username}/.ssh"
      "/home/${username}/.gnupg/private-keys-v1.d"
      "/home/${username}/.config/sops/age"
      "/home/${username}/.config/age"
      "/home/${username}/.claude/.credentials.json"
    ];
  };

  # vLLM OpenAI-compatible inference server (Podman container, vllm-openai image).
  # Models cached to /var/lib/vllm/huggingface on first run.
  #
  # Model: Qwen2.5-Coder-7B, official Qwen AWQ quant. Dense, fits fully in
  # VRAM (llmfit "Perfect", ~51% utilization, ~52 tok/s est.), non-thinking —
  # picked for agentic use in opencode where the 30B MoE's ~20 tok/s and
  # hybrid thinking (turns can end with empty content, looks like a stall)
  # were the bottleneck. Prefer official Qwen/ or RedHatAI/ repos over
  # community quants.
  #
  # Alternatives for RTX 3060 (12GB VRAM) + 62GB RAM, via `llmfit fit`
  # (runtime=vLLM). Verified 2026-07-06 — re-verify before switching.
  #
  #   MoE (need cpuOffloadGb = 10, weights > 12 GB):
  #     Qwen/Qwen3-30B-A3B-GPTQ-Int4               # tested 2026-07-06: works, 20 tok/s
  #                                                # measured KV headroom 61k tok, smartest
  #     Qwen/Qwen3-30B-A3B-Instruct-2507           # bf16 ~61GB — too big even offloaded
  #     Qwen/Qwen3-Coder-30B-A3B-Instruct          # coder-tuned, bf16 — same problem
  #
  #   Dense, fit fully in VRAM (no cpuOffloadGb, faster per token):
  #     Qwen/Qwen2.5-Coder-7B-Instruct-AWQ         # current pick, coder, 32K ctx
  #     Qwen/Qwen3-8B-AWQ                          # earlier pick, thinking, 41K ctx
  #     RedHatAI/Meta-Llama-3.1-8B-Instruct-quantized.w4a16  # 1M model ctx, 49 tok/s
  #
  #   Notes:
  #     - Kimi K2 (16M ctx!) is GGUF/llama.cpp only — not vLLM-compatible.
  #     - Re-run `llmfit --memory 12G fit` to refresh the shortlist.
  services.vllm = {
    # Disabled — not currently in use. Flip back to true (and re-pull the image
    # + models) to bring the inference server back. All tuning notes below kept.
    enable = false;
    model = "Qwen/Qwen2.5-Coder-7B-Instruct-AWQ";
    # To switch back to the 30B MoE: swap the model lines and re-enable
    # cpuOffloadGb below. Both models are listed in the opencode provider
    # config (opencode.nix), so no client change is needed.
    # model = "Qwen/Qwen3-30B-A3B-GPTQ-Int4";
    port = 10808;
    host = "0.0.0.0";
    maxModelLen = 32768; # Qwen2.5-Coder-7B's native max context.
    # (30B MoE note: its model max is 40960 and measured KV headroom was
    # 61,744 tokens at this budget — it could run at the full 40960.)
    # 0.80 of 11.61 GiB ≈ 9.3 GiB. Hyprland/Wayland holds ~1.5 GiB for the
    # compositor, so 0.9 (10.45 GiB) overshoots the free pool on this host.
    gpuMemoryUtilization = 0.80;
    # cpuOffloadGb is only needed for the 30B MoE (15.6 GB weights vs ~9.3 GiB
    # GPU budget). The 7B fits fully in VRAM — offload would only slow it down.
    # cpuOffloadGb = 10;
    huggingfaceTokenFile = config.age.secrets.hf-token.path;
    extraArgs = [
      "--kv-cache-dtype"
      "fp8" # Quantize KV cache to save VRAM
      # Tool calling (required by opencode and other agentic clients).
      # "hermes" is the correct parser for both Qwen3 and Qwen2.5 models.
      "--enable-auto-tool-choice"
      "--tool-call-parser"
      "hermes"
      # NOTE: --reasoning-parser qwen3 was removed here. It is NOT harmless for
      # non-thinking models: Qwen3ReasoningParser aborts at startup if the
      # tokenizer has no <think>/</think> tokens, which Qwen2.5-Coder lacks
      # ("could not locate think start/end tokens"). Re-add it only when
      # switching back to the Qwen3-30B MoE model above.
      # Disables torch.compile + CUDA graph capture. Kept because CUDA graphs
      # cost extra VRAM we don't have, and --cpu-offload-gb is best supported
      # in eager mode. Try removing only after the model swap is proven stable.
      "--enforce-eager"
    ];
  };

  # Swap on zram — helps avoid OOM during large builds and LLM inference
  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 50;
  };

  # System state version
  system.stateVersion = "24.11";

  # Ensure storage mount is owned by the primary user and create models directory
  systemd.tmpfiles.rules = [
    "Z /mnt/storage 0755 ${username} users -"
    "d /home/${username}/models 0755 ${username} users -"
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

  age.secrets.hf-token = {
    file = ../../secrets/hf-token.age;
    mode = "440";
    # Owned by root so the vllm systemd service can read it via EnvironmentFile.
    # Format inside the file: HF_TOKEN=hf_xxxxxxxxxxxxxxxxxxxx
  };

  age.secrets.axon-gateway-env = {
    file = ../../secrets/axon-gateway-env.age;
    mode = "440";
    owner = username;
    group = "users";
    # Format inside the file: AXON_GATEWAY_TOKEN=ABC123
  };

  age.secrets.opencode-server-password = {
    file = ../../secrets/opencode-server-password.age;
    mode = "440";
    owner = username;
    group = "users";
    # Format inside the file: OPENCODE_SERVER_PASSWORD=xxxx
  };

  # Environment variables
  environment.sessionVariables = {
    # Agenix secrets
    CONTEXT7_API_KEY_FILE = config.age.secrets.context7-api-key.path;
    AXON_GATEWAY_TOKEN_FILE = config.age.secrets.axon-gateway-env.path;
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
