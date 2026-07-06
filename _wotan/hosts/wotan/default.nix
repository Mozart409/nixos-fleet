{
  config,
  pkgs,
  inputs,
  lib,
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

    # Common modules
    ../../modules/nixos/common-packages.nix
    ../../modules/nixos/security.nix
    ../../modules/nixos/razer.nix
    ../../modules/nixos/moza.nix
    ../../modules/nixos/vllm.nix
    ../../modules/nixos/desktop/default.nix
    ../../modules/nixos/desktop/hyprland.nix
    ../../modules/nixos/desktop/file-managers.nix
    ../../modules/nixos/desktop/user-experience.nix

    # Desktop configuration
    ./desktop-config.nix
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

  # Enable aarch64 emulation for cross-compilation (e.g., building aarch64 ISOs)
  boot.binfmt.emulatedSystems = ["aarch64-linux"];

  # Desktop environment configuration
  desktop.enable = true;

  # Security hardening
  security.hardening = {
    enable = true;
    firewall.allowedTCPPorts = [
      10808 # vLLM OpenAI-compatible API
    ];
    audit.enable = false; # Enable for security auditing (generates logs)
  };

  # Display manager auto-login (KDE specific)
  services.displayManager.autoLogin = lib.mkIf (config.desktop.environment == "kde") {
    enable = true;
    user = "amadeus";
  };

  # Razer device support
  hardware.razer.enable = true;

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

  virtualisation.containers.registries.search = ["docker.io"];
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

  # vLLM OpenAI-compatible inference server (Podman container, vllm-openai image).
  # Models cached to /var/lib/vllm/huggingface on first run.
  #
  # Model: Qwen3-30B-A3B MoE, official Qwen GPTQ-Int4 quant. Weights are
  # 15.6 GB — more than the 3060's 12 GB — so ~10 GiB of (mostly inactive-
  # expert) weights are offloaded to system RAM via --cpu-offload-gb.
  # llmfit rates the fit "Good" in MoE-offload mode: ~3.6 GB active experts
  # in VRAM, ~19 tok/s estimated. Only ~3B params are active per token.
  # Prefer official Qwen/ or RedHatAI/ repos over community quants.
  #
  # Alternatives for RTX 3060 (12GB VRAM) + 62GB RAM, via `llmfit fit`
  # (runtime=vLLM). Verified 2026-07-06 — re-verify before switching.
  #
  #   MoE (need cpuOffloadGb, weights > 12 GB):
  #     Qwen/Qwen3-30B-A3B-GPTQ-Int4               # current pick, 40K ctx
  #     Qwen/Qwen3-30B-A3B-Instruct-2507           # bf16 ~61GB — too big even offloaded
  #     Qwen/Qwen3-Coder-30B-A3B-Instruct          # coder-tuned, bf16 — same problem
  #
  #   Dense, fit fully in VRAM (drop cpuOffloadGb, faster per token):
  #     Qwen/Qwen3-8B-AWQ                          # previous pick, 41K ctx
  #     Qwen/Qwen2.5-7B-Instruct-GPTQ-Int4         # 33K ctx, 52 tok/s, ~50% VRAM
  #     RedHatAI/Meta-Llama-3.1-8B-Instruct-quantized.w4a16  # 1M model ctx, 49 tok/s
  #
  #   Notes:
  #     - Kimi K2 (16M ctx!) is GGUF/llama.cpp only — not vLLM-compatible.
  #     - Re-run `llmfit --memory 12G fit` to refresh the shortlist.
  services.vllm = {
    enable = true;
    model = "Qwen/Qwen3-30B-A3B-GPTQ-Int4";
    # NEXT TEST — dense coder, fits fully in VRAM (llmfit "Perfect", ~51%
    # utilization, ~52 tok/s est., 32K native ctx). To switch: uncomment the
    # line below, comment out the 30B line above, and REMOVE cpuOffloadGb
    # (not needed when weights fit in VRAM — offload only slows it down).
    # Also listed in the opencode provider config (opencode.nix).
    # model = "Qwen/Qwen2.5-Coder-7B-Instruct-AWQ";
    port = 10808;
    host = "0.0.0.0";
    maxModelLen = 32768; # Model max is 40960. KV at fp8 is ~24 KB/token
    # (48 layers × 4 KV heads × 128 dim, GQA), so 32K ctx ≈ 0.75 GiB —
    # cheap next to the weights. Raise toward 40960 if no OOM during prefill.
    # 0.80 of 11.61 GiB ≈ 9.3 GiB. Hyprland/Wayland holds ~1.5 GiB for the
    # compositor, so 0.9 (10.45 GiB) overshoots the free pool on this host.
    gpuMemoryUtilization = 0.80;
    # Weights are 15.6 GB vs ~9.3 GiB GPU budget: offload 10 GiB to RAM,
    # keeping ~5.6 GiB on GPU + headroom for KV cache and activations.
    # More offload = slower (PCIe-bound); lower this if a smaller model is used.
    cpuOffloadGb = 10;
    huggingfaceTokenFile = config.age.secrets.hf-token.path;
    extraArgs = [
      "--kv-cache-dtype"
      "fp8" # Quantize KV cache to save VRAM
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

  # Ensure storage mount is owned by amadeus and create models directory
  systemd.tmpfiles.rules = [
    "Z /mnt/storage 0755 amadeus users -"
    "d /home/amadeus/models 0755 amadeus users -"
  ];

  # Agenix secrets configuration
  age.identityPaths = [
    "/etc/ssh/ssh_host_ed25519_key"
  ];

  age.secrets.context7-api-key = {
    file = ../../secrets/context7-api-key.age;
    mode = "440";
    owner = "amadeus";
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
    owner = "amadeus";
    group = "users";
    # Format inside the file: AXON_GATEWAY_TOKEN=ABC123
  };

  # Environment variables
  environment.sessionVariables = {
    # Agenix secrets
    CONTEXT7_API_KEY_FILE = config.age.secrets.context7-api-key.path;
    AXON_GATEWAY_TOKEN_FILE = config.age.secrets.axon-gateway-env.path;

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
