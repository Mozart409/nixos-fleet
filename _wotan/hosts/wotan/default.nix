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

  # vLLM OpenAI-compatible inference server.
  # Models cached to /var/lib/vllm/huggingface on first run.
  # Model: Qwen3-8B dense AWQ. Picked because vLLM 0.16.0 in nixpkgs does NOT
  # support the newer Qwen3.5/3.6 architectures (`Qwen3_5MoeForConditionalGeneration`
  # is missing from the registry; only `Qwen3MoeForCausalLM` / `Qwen3ForCausalLM`
  # are recognized). When nixpkgs bumps vllm to >= 0.18, revisit and switch to a
  # Qwen3.5 MoE quant for huge context.
  # Official Qwen quant — important because vllm 0.16.0 has CVE-2026-27893 (RCE
  # via hardcoded trust_remote_code), so we MUST stick to trusted repos.
  #
  # Alternative models for RTX 3060 (12GB VRAM) + 62GB RAM. Trust-tier matters
  # while CVE-2026-27893 is unpatched — prefer Qwen/ official, then RedHatAI/.
  # All picked via `llmfit fit` (runtime=vLLM, mode=GPU, fit=Perfect/Good).
  # Verified 2026-06-06 — re-verify before switching, repos may move/disappear.
  #
  #   Official Qwen3 (vllm 0.16-compatible architectures only):
  #     Qwen/Qwen3-8B-AWQ                          # current pick, dense, 41K ctx
  #     Qwen/Qwen3-30B-A3B-Instruct-2507           # MoE 262K ctx, needs CPU offload
  #     Qwen/Qwen3-Coder-30B-A3B-Instruct          # MoE coder-tuned, 262K ctx
  #
  #   Official Qwen3.5/3.6 MoE (waiting on vllm >= 0.18):
  #     Qwen/Qwen3.5-35B-A3B-GPTQ-Int4             # 262K ctx, 22 tok/s
  #
  #   Other dense alternatives:
  #     Qwen/Qwen2.5-7B-Instruct-GPTQ-Int4         # 33K ctx, 52 tok/s, ~50% VRAM
  #     RedHatAI/Meta-Llama-3.1-8B-Instruct-quantized.w4a16  # 1M model ctx, 49 tok/s
  #
  #   Notes:
  #     - Kimi K2 (16M ctx!) is GGUF/llama.cpp only — not vLLM-compatible.
  #     - Community MoE quants exist (QuantTrio, Chunity, stelterlab) but most
  #       are Qwen3.5/3.6 — same vllm-0.16 architecture mismatch.
  #     - Re-run `llmfit --memory 12G fit` to refresh the shortlist.
  services.vllm = {
    enable = true;
    model = "Qwen/Qwen3-8B-AWQ";
    port = 10808;
    host = "0.0.0.0";
    maxModelLen = 28672; # 28K — bounded by ~2.15 GiB KV-cache budget on RTX 3060.
    # vLLM reported "estimated maximum model length is 31296" at gpu_mem=0.80.
    # Bump up if you raise gpuMemoryUtilization; lower if you see OOM during prefill.
    # 0.80 of 11.61 GiB ≈ 9.3 GiB. Hyprland/Wayland holds ~1.5 GiB for the
    # compositor, so 0.9 (10.45 GiB) overshoots the free pool on this host.
    gpuMemoryUtilization = 0.80;
    huggingfaceTokenFile = config.age.secrets.hf-token.path;
    extraArgs = [
      "--kv-cache-dtype"
      "fp8" # Quantize KV cache to save VRAM
      # Disables torch.compile + CUDA graph capture. Kept as a safeguard
      # because the nixpkgs vllm 0.16.0 build can be flaky with Inductor.
      # NOTE: vLLM now runs inside a Podman container (vllm/vllm-openai),
      # so the old Triton .so permission crash is no longer an issue.
      # TODO: try removing this flag once the container image ships vllm >= 0.20.
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
